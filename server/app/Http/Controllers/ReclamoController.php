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
}
