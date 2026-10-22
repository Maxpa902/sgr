<?php

namespace App\Http\Controllers;

use App\Http\Resources\ReclamoMapaResource;
use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use Illuminate\Support\Facades\Http;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
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
        ]);

        $estados = $filtros['estados'] ?? EstadoReclamo::ACTIVOS;

        $reclamos = Reclamo::query()
            ->publicos()
            ->whereHas('estado', fn (Builder $query) => $query->whereIn('nombre', $estados))
            ->when(
                isset($filtros['tipos']),
                fn (Builder $query) => $query->whereIn('tipo_reclamo_id', $filtros['tipos']),
            )
            ->with(['tipoReclamo', 'estado'])
            ->withCount([
                'votos as confirmaciones_count' => fn (Builder $query) => $query->where('valor', 'confirma'),
                'votos as desmentidas_count' => fn (Builder $query) => $query->where('valor', 'desmiente'),
            ])
            ->latest()
            ->get();

        return ReclamoMapaResource::collection($reclamos);
    }

    // En ReclamoController.php

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
    ]);

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

    $reclamo = $request->user()->reclamos()->create([
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

    // Cargar relaciones necesarias para ReclamoMapaResource
    $reclamo->load(['tipoReclamo', 'estado']);
    $reclamo->confirmaciones_count = 0;
    $reclamo->desmentidas_count = 0;

    return (new ReclamoMapaResource($reclamo))
        ->response()
        ->setStatusCode(201);
}
}