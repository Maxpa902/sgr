<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request; 
use App\Http\Resources\ReclamoMapaResource; 
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\Rule;

class ReclamoController extends Controller
{
    /**
     * Lista los reclamos públicos para el mapa. Sin filtro de estados devuelve solo los activos.
     * Acepta varios estados y categorías: `?estados[]=pendiente&estados[]=resuelto&tipos[]=3`.
     */



    public function index(Request $request): AnonymousResourceCollection
    {
        $filtros = $request->validate([
            'estados' => ['sometimes', 'array'],
            'estados.*' => ['string', Rule::exists('estados_reclamo', 'nombre')],
            'tipos' => ['sometimes', 'array'],
            'tipos.*' => ['integer', Rule::exists('tipos_reclamo', 'id')],
            'mis_reclamos' => ['sometimes', 'boolean'],
        ]);

        $usuarioId = $request->user()?->id;
        $query = Reclamo::query();

        if ($request->boolean('mis_reclamos')) {
            $query->where(function (Builder $q) use ($usuarioId) {
                $q->where('usuario_id', $usuarioId)
                    ->orWhereHas('votos', fn(Builder $vq) => $vq->where('usuario_id', $usuarioId));
            });
        } else {
            $estados = $filtros['estados'] ?? EstadoReclamo::ACTIVOS;
            $query->publicos()
                ->whereHas('estado', fn(Builder $q) => $q->whereIn('nombre', $estados));
        }

        $reclamos = $query
            ->when(
                isset($filtros['tipos']),
                fn(Builder $q) => $q->whereIn('tipo_reclamo_id', $filtros['tipos']),
            )
            ->with(['tipoReclamo', 'estado', 'fotos'])
            ->withCount([
                'votos as confirmaciones_count' => fn(Builder $q) => $q->where('valor', 'confirma'),
                'votos as desmentidas_count' => fn(Builder $q) => $q->where('valor', 'desmiente'),
            ])
            ->latest()
            ->get();

        return ReclamoMapaResource::collection($reclamos);
    }


    public function store(Request $request)
    {
        $validated = $request->validate([
            'titulo' => 'required|string|max:255',
            'descripcion' => 'required|string',
            'tipo_reclamo_id' => 'required|exists:tipos_reclamo,id',
            'latitud' => 'required|numeric',
            'longitud' => 'required|numeric',
            'direccion' => 'nullable|string|max:255',
            'foto' => 'nullable|image|max:10240',
            'forzar_creacion' => 'nullable|boolean',
        ]);


        $usuario = $request->user();

        // NUEVO: Verificar si el usuario está suspendido
        if ($usuario->suspendido_hasta && now()->lt($usuario->suspendido_hasta)) {
            return response()->json([
                'message' => 'Tu cuenta está suspendida temporalmente para crear reclamos debido a reportes anteriores falsos.',
            ], 403); // Código 403 Forbidden o 422
        }

        $reclamosActivos = $usuario->reclamos()
            ->whereIn('estado_id', [1, 2])
            ->count();

        if ($reclamosActivos >= 3) {
            return response()->json([
                'message' => 'Llegaste al límite de 3 reclamos activos. Esperá a que se resuelvan para cargar uno nuevo.',
            ], 422);
        }

        $forzarCreacion = $request->boolean('forzar_creacion');

        if (! $forzarCreacion) {
            $radioGrados = 0.00045;

            $reclamoExistente = Reclamo::where('tipo_reclamo_id', $validated['tipo_reclamo_id'])
                ->whereIn('estado_id', [1, 2])
                ->whereBetween('latitud', [$validated['latitud'] - $radioGrados, $validated['latitud'] + $radioGrados])
                ->whereBetween('longitud', [$validated['longitud'] - $radioGrados, $validated['longitud'] + $radioGrados])
                ->first();

            if ($reclamoExistente) {
                $reclamoExistente->load(['tipoReclamo', 'estado', 'fotos']);
                $reclamoExistente->confirmaciones_count = $reclamoExistente->votos()->where('valor', 'confirma')->count();
                $reclamoExistente->desmentidas_count = $reclamoExistente->votos()->where('valor', 'desmiente')->count();

                return response()->json([
                    'message' => 'Existe un reclamo activo cercano de esta categoría.',
                    'reclamo_duplicado' => new ReclamoMapaResource($reclamoExistente),
                ], 409);
            }
        }

        // 1. MODERACIÓN CON IA (Sightengine)
        // Se ejecuta solo si el usuario adjuntó una foto
        if ($request->hasFile('foto')) {
           $rechazo = $this->moderarFoto($request->file('foto')); if ($rechazo) return $rechazo;
        }

        

        // 2. GEOCODIFICACIÓN INVERSA (Código de tu compañera)
        $direccion = $validated['direccion'] ?? null;

        if (! $direccion) {
            try {
                $response = Http::withHeaders([
                    'User-Agent' => 'SGR-App/1.0',
                ])->get('https://nominatim.openstreetmap.org/reverse', [
                    'format' => 'json',
                    'lat' => $validated['latitud'],
                    'lon' => $validated['longitud'],
                    'zoom' => 18,
                ]);

                if ($response->successful()) {
                    $address = $response->json('address');
                    $barrio = $address['suburb'] ?? $address['neighbourhood'] ?? $address['city_district'] ?? '';
                    $calle = $address['road'] ?? '';
                    $direccion = trim("$barrio $calle");
                }
            } catch (\Throwable $e) {
                // Ignorar error de API externa
            }
        }

        $pendiente = EstadoReclamo::where('nombre', 'pendiente')->firstOrFail();
        $reclamo = DB::transaction(function () use ($usuario, $validated, $direccion, $pendiente) {
            $reclamo = $usuario->reclamos()->create([
                'titulo' => $validated['titulo'],
                'descripcion' => $validated['descripcion'],
                'tipo_reclamo_id' => $validated['tipo_reclamo_id'],
                'latitud' => $validated['latitud'],
                'longitud' => $validated['longitud'],
                'direccion' => $direccion,
                'estado_id' => $pendiente->id,
            ]);
            $reclamo->historialEstados()->create([
                'estado_id' => $pendiente->id,
                'usuario_id' => $usuario->id,
                'visibilidad' => 'publica',
                'created_at' => $reclamo->created_at,
            ]);

            return $reclamo;
        });

        if ($request->hasFile('foto')) {
            $path = $request->file('foto')->store('reclamos', 'public');
            $reclamo->fotos()->create(['ruta' => $path]);
        }

        $reclamo->load(['tipoReclamo', 'estado', 'fotos']);
        $reclamo->confirmaciones_count = 0;
        $reclamo->desmentidas_count = 0;

        return (new ReclamoMapaResource($reclamo))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * Edita un reclamo propio mientras esté pendiente y el usuario no esté suspendido.
     */
    public function update(Request $request, Reclamo $reclamo): JsonResponse
    {
        $usuario = $request->user();

        // 1. Validar autoría
        if ($reclamo->usuario_id !== $usuario->id) {
            return response()->json([
                'message' => 'No tenés permiso para editar este reclamo.',
            ], 403);
        }

        // 2. Validar que la cuenta no esté suspendida
        if ($usuario->suspendido_hasta && now()->lt($usuario->suspendido_hasta)) {
            return response()->json([
                'message' => 'Tu cuenta está suspendida temporalmente y no podés editar reclamos.',
            ], 403);
        }

        // 3. Validar que el estado sea 'pendiente' (SoftDeletes ya devuelve 404 si tiene deleted_at)
        $reclamo->loadMissing('estado');
        if ($reclamo->estado?->nombre !== 'pendiente') {
            return response()->json([
                'message' => 'Solo se pueden editar reclamos que estén en estado pendiente.',
            ], 422);
        }

        // 4. Validar campos editables (no permite cambiar usuario_id, estado_id ni tipo_reclamo_id)
        $validated = $request->validate([
            'titulo' => ['sometimes', 'nullable', 'string', 'max:150'],
            'descripcion' => ['sometimes', 'required', 'string'],
            'latitud' => ['sometimes', 'required', 'numeric'],
            'longitud' => ['sometimes', 'required', 'numeric'],
            'direccion' => ['sometimes', 'nullable', 'string', 'max:255'],
            'foto' => ['sometimes', 'nullable', 'image', 'max:10240'],
            'fotos' => ['sometimes', 'array', 'max:5'],
            'fotos.*' => ['image', 'max:10240'],
            'fotos_eliminar' => ['sometimes', 'array'],
            'fotos_eliminar.*' => ['integer'],
        ]);

        // 5. Validar cantidad resultante de fotos (entre 1 y 5)
        $idsEliminar = collect($validated['fotos_eliminar'] ?? [])->unique();
        $fotosActualesIds = $reclamo->fotos()->pluck('id');

        if ($idsEliminar->diff($fotosActualesIds)->isNotEmpty()) {
            return response()->json([
                'message' => 'Una o más fotos indicadas para eliminar no pertenecen a este reclamo.',
            ], 422);
        }

        $archivosNuevos = [];
        if ($request->hasFile('fotos')) {
            $archivosNuevos = $request->file('fotos');
        } elseif ($request->hasFile('foto')) {
            $archivosNuevos = [$request->file('foto')];
        }

        $cantidadActual = $fotosActualesIds->count();
        $cantidadFinal = $cantidadActual - $idsEliminar->count() + count($archivosNuevos);

        if ($cantidadFinal > 5) {
            return response()->json([
                'message' => 'Un reclamo puede tener como máximo 5 fotos.',
            ], 422);
        }

        if ($cantidadActual > 0 && $cantidadFinal < 1) {
            return response()->json([
                'message' => 'El reclamo debe conservar al menos una foto.',
            ], 422);
        }

        // 6. Pasar cada foto nueva por moderación IA (Sightengine)
        foreach ($archivosNuevos as $archivo) {
            $rechazo = $this->moderarFoto($archivo);
            if ($rechazo !== null) {
                return $rechazo;
            }
        }

        // 7. Actualizar dirección si cambiaron coordenadas y no vino dirección explícita
        $datosActualizar = collect($validated)
            ->only(['titulo', 'descripcion', 'latitud', 'longitud', 'direccion'])
            ->toArray();

        $cambioUbicacion = array_key_exists('latitud', $datosActualizar) || array_key_exists('longitud', $datosActualizar);
        if ($cambioUbicacion && ! array_key_exists('direccion', $datosActualizar)) {
            $lat = $datosActualizar['latitud'] ?? $reclamo->latitud;
            $lng = $datosActualizar['longitud'] ?? $reclamo->longitud;

            try {
                $response = Http::withHeaders([
                    'User-Agent' => 'SGR-App/1.0',
                ])->get('https://nominatim.openstreetmap.org/reverse', [
                    'format' => 'json',
                    'lat' => $lat,
                    'lon' => $lng,
                    'zoom' => 18,
                ]);

                if ($response->successful()) {
                    $address = $response->json('address');
                    $barrio = $address['suburb'] ?? $address['neighbourhood'] ?? $address['city_district'] ?? '';
                    $calle = $address['road'] ?? '';
                    $datosActualizar['direccion'] = trim("$barrio $calle");
                }
            } catch (\Throwable $e) {
                // Ignorar error de API externa
            }
        }

        // 8. Guardar cambios y fotos en transacción
        DB::transaction(function () use ($reclamo, $datosActualizar, $idsEliminar, $archivosNuevos): void {
            if (! empty($datosActualizar)) {
                $reclamo->update($datosActualizar);
            }

            if ($idsEliminar->isNotEmpty()) {
                $fotosABorrar = $reclamo->fotos()->whereIn('id', $idsEliminar)->get();
                foreach ($fotosABorrar as $foto) {
                    Storage::disk('public')->delete($foto->ruta);
                    $foto->delete();
                }
            }

            foreach ($archivosNuevos as $archivo) {
                $path = $archivo->store('reclamos', 'public');
                $reclamo->fotos()->create(['ruta' => $path]);
            }
        });

        $reclamo->load(['tipoReclamo', 'estado', 'fotos']);
        $reclamo->confirmaciones_count = $reclamo->votos()->where('valor', 'confirma')->count();
        $reclamo->desmentidas_count = $reclamo->votos()->where('valor', 'desmiente')->count();

        return (new ReclamoMapaResource($reclamo))
            ->response()
            ->setStatusCode(200);
    }

    /**
     * Da de baja lógica (soft delete) un reclamo propio si sigue pendiente y nunca cambió de estado.
     */
    public function destroy(Request $request, Reclamo $reclamo): JsonResponse
    {
        $usuario = $request->user();

        // 1. Validar autoría
        if ($reclamo->usuario_id !== $usuario->id) {
            return response()->json([
                'message' => 'No tenés permiso para eliminar este reclamo.',
            ], 403);
        }

        // 2. Validar que siga pendiente y nunca haya cambiado de estado
        $reclamo->loadMissing('estado');
        $tuvoCambioDeEstado = $reclamo->historialEstados()
            ->where('estado_id', '!=', $reclamo->estado_id)
            ->exists();

        if ($reclamo->estado?->nombre !== 'pendiente' || $tuvoCambioDeEstado) {
            return response()->json([
                'message' => 'Solo se pueden eliminar reclamos propios que sigan pendientes y nunca hayan cambiado de estado.',
            ], 422);
        }

        // 3. Baja lógica (conserva fotos, historial, votos y comentarios para administración)
        $reclamo->delete();

        return response()->json([
            'message' => 'Reclamo eliminado correctamente.',
        ], 200);
    }

    /**
     * Evalúa una imagen con Sightengine. Devuelve una JsonResponse 422 si se rechaza, o null si es válida.
     */
    private function moderarFoto(UploadedFile $file): ?JsonResponse
    {
        try {
            $sightengineResponse = Http::attach(
                'media',
                file_get_contents($file->path()),
                $file->getClientOriginalName()
            )->post('https://api.sightengine.com/1.0/check.json', [
                'models'     => 'nudity-2.0,gore,face-attributes',
                'api_user'   => config('services.sightengine.user'),
                'api_secret' => config('services.sightengine.secret'),
            ]);
        } catch (\Throwable $e) {
            return null;
        }

        if (! $sightengineResponse->successful()) {
            return null;
        }

        $result = $sightengineResponse->json();
        $nudity = $result['nudity'] ?? [];
        $classes = $nudity['suggestive_classes'] ?? [];
        $faces   = $result['faces'] ?? [];

        $rawNudity      = $nudity['raw'] ?? 0;
        $erotica        = $nudity['erotica'] ?? 0;
        $sexualActivity = $nudity['sexual_activity'] ?? 0;
        $goreProb       = $result['gore']['prob'] ?? 0;

        $suggestive    = $nudity['suggestive'] ?? 0;
        $bikini        = $classes['bikini'] ?? 0;
        $maleChest     = $classes['male_chest'] ?? 0;
        $lingerie      = $classes['lingerie'] ?? 0;
        $maleUnderwear = $classes['male_underwear'] ?? 0;

        if ($rawNudity > 0.50 || $sexualActivity > 0.50 || $goreProb > 0.50) {
            return response()->json([
                'message' => 'La foto fue rechazada por contener material indebido, sexual o gore.',
            ], 422);
        }

        if ($erotica > 0.50 || $bikini > 0.20 || $lingerie > 0.20 || $maleUnderwear > 0.20 || $suggestive > 0.40) {
            return response()->json([
                'message' => 'La foto fue rechazada por contener material erótico o vestimenta inapropiada.',
            ], 422);
        }

        if (count($faces) > 0 || $maleChest > 0.20) {
            return response()->json([
                'message' => 'La foto fue rechazada. No se permiten personas en la imagen, solo la infraestructura o el daño público.',
            ], 422);
        }

        return null;
    }



}
