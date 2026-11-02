<?php

namespace App\Http\Controllers;

use App\Http\Resources\ReclamoAdminDetalleResource;
use App\Http\Resources\ReclamoTrabajoResource;
use App\Models\Reclamo;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class ReclamoTrabajoListadoController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $filtros = $request->validate([
            'vista' => ['required', Rule::in(['asignados', 'disponibles'])],
            'cursor' => ['nullable', 'string'],
        ]);

        $query = Reclamo::query()
            ->with(['tipoReclamo', 'estado']);

        if ($filtros['vista'] === 'asignados') {
            $query->where('responsable_id', $request->user()->id)
                ->whereHas('estado', fn ($estado) => $estado->whereIn('nombre', ['pendiente', 'en_proceso']));
        } else {
            $query->whereNull('responsable_id')
                ->whereHas('estado', fn ($estado) => $estado->where('nombre', 'pendiente'));
        }

        $total = (clone $query)->count();
        $reclamos = $query->orderByDesc('created_at')->orderByDesc('id')
            ->cursorPaginate(30)
            ->appends($request->only(['vista']));

        return ReclamoTrabajoResource::collection($reclamos)
            ->additional(['meta' => ['total' => $total]]);
    }

    public function show(Reclamo $reclamo): ReclamoAdminDetalleResource
    {
        $reclamo->load([
            'tipoReclamo', 'estado', 'usuario', 'fotos', 'responsable',
            'asignadoPor', 'ultimoResponsable', 'desasignadoPor',
            'historialEstados' => fn ($query) => $query
                ->with(['estado', 'usuario'])
                ->orderBy('created_at')->orderBy('id'),
        ]);

        return new ReclamoAdminDetalleResource($reclamo);
    }
}
