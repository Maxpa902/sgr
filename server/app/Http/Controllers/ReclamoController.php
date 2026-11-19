<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request; // <--- Asegúrate de tener este
use App\Http\Resources\ReclamoMapaResource; // <--- Y este si usas recursos
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
            $file = $request->file('foto');

            $sightengineResponse = Http::attach(
                'media',
                file_get_contents($file->path()),
                $file->getClientOriginalName()
            )->post('https://api.sightengine.com/1.0/check.json', [
                'models'     => 'nudity-2.0,gore,face-attributes',
                'api_user'   => config('services.sightengine.user'),
                'api_secret' => config('services.sightengine.secret'),
            ]);

            if ($sightengineResponse->successful()) {
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

                // Frena la petición si hay rostros/personas, gore o vestimenta/contenido inapropiado
                // 1. Contenido indebido, sexual explícito o gore
                if ($rawNudity > 0.50 || $sexualActivity > 0.50 || $goreProb > 0.50) {
                    return response()->json([
                        'message' => 'La foto fue rechazada por contener material indebido, sexual o gore.'
                    ], 422);
                }

                // 2. Contenido erótico, bikini o vestimenta sugestiva
                if ($erotica > 0.50 || $bikini > 0.20 || $lingerie > 0.20 || $maleUnderwear > 0.20 || $suggestive > 0.40) {
                    return response()->json([
                        'message' => 'La foto fue rechazada por contener material erótico o vestimenta inapropiada.'
                    ], 422);
                }

                // 3. Presencia de personas, rostros o torsos al descubierto
                if (count($faces) > 0 || $maleChest > 0.20) {
                    return response()->json([
                        'message' => 'La foto fue rechazada. No se permiten personas en la imagen, solo la infraestructura o el daño público.'
                    ], 422);
                }
            }
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
}
