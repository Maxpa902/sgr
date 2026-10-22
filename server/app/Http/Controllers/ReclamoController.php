<?php

namespace App\Http\Controllers;

use App\Http\Resources\ReclamoMapaResource;
use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
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
                  ->orWhereHas('votos', fn (Builder $vq) => $vq->where('usuario_id', $usuarioId));
            });
        } else {
            $estados = $filtros['estados'] ?? EstadoReclamo::ACTIVOS;
            $query->publicos()
                ->whereHas('estado', fn (Builder $q) => $q->whereIn('nombre', $estados));
        }

        $reclamos = $query
            ->when(
                isset($filtros['tipos']),
                fn (Builder $q) => $q->whereIn('tipo_reclamo_id', $filtros['tipos']),
            )
            ->with(['tipoReclamo', 'estado', 'fotos'])
            ->withCount([
                'votos as confirmaciones_count' => fn (Builder $q) => $q->where('valor', 'confirma'),
                'votos as desmentidas_count' => fn (Builder $q) => $q->where('valor', 'desmiente'),
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

        $reclamo = $usuario->reclamos()->create([
            'titulo' => $validated['titulo'],
            'descripcion' => $validated['descripcion'],
            'tipo_reclamo_id' => $validated['tipo_reclamo_id'],
            'latitud' => $validated['latitud'],
            'longitud' => $validated['longitud'],
            'direccion' => $direccion,
            'estado_id' => 1,
        ]);

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