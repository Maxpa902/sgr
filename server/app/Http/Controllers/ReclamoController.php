<?php

namespace App\Http\Controllers;

use App\Http\Resources\ReclamoMapaResource;
use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class ReclamoController extends Controller
{
    /**
     * Lista los reclamos públicos para el mapa. Sin filtro de estado devuelve solo los activos.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $filtros = $request->validate([
            'estado' => ['sometimes', 'string', Rule::exists('estados_reclamo', 'nombre')],
            'tipo_reclamo_id' => ['sometimes', 'integer', Rule::exists('tipos_reclamo', 'id')],
        ]);

        $estados = isset($filtros['estado']) ? [$filtros['estado']] : EstadoReclamo::ACTIVOS;

        $reclamos = Reclamo::query()
            ->publicos()
            ->whereHas('estado', fn (Builder $query) => $query->whereIn('nombre', $estados))
            ->when(
                isset($filtros['tipo_reclamo_id']),
                fn (Builder $query) => $query->where('tipo_reclamo_id', $filtros['tipo_reclamo_id']),
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
}
