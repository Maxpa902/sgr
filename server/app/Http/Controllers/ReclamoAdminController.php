<?php

namespace App\Http\Controllers;

use App\Http\Resources\ReclamoAdminResource;
use App\Models\Reclamo;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class ReclamoAdminController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $filtros = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'estado' => ['nullable', 'string', Rule::exists('estados_reclamo', 'nombre')],
            'tipo' => ['nullable', 'integer', Rule::exists('tipos_reclamo', 'id')],
            'cursor' => ['nullable', 'string'],
        ]);

        $query = Reclamo::query()->with(['tipoReclamo', 'estado', 'usuario']);
        $terminos = preg_split('/\s+/', trim($filtros['q'] ?? ''), -1, PREG_SPLIT_NO_EMPTY) ?: [];

        foreach ($terminos as $termino) {
            $query->where(function (Builder $query) use ($termino): void {
                $busqueda = "%{$termino}%";
                $query->where('titulo', 'like', $busqueda)
                    ->orWhere('descripcion', 'like', $busqueda)
                    ->orWhere('direccion', 'like', $busqueda)
                    ->orWhereHas(
                        'tipoReclamo',
                        fn (Builder $tipo) => $tipo->where('nombre', 'like', $busqueda),
                    )
                    ->orWhereHas('usuario', fn (Builder $usuario) => $usuario
                        ->where('nombre', 'like', $busqueda)
                        ->orWhere('apellido', 'like', $busqueda)
                        ->orWhere('email', 'like', $busqueda));
            });
        }

        $query
            ->when(isset($filtros['estado']), fn (Builder $q) => $q->whereHas(
                'estado', fn (Builder $estado) => $estado->where('nombre', $filtros['estado']),
            ))
            ->when(isset($filtros['tipo']), fn (Builder $q) => $q->where('tipo_reclamo_id', $filtros['tipo']));

        $total = (clone $query)->count();
        $reclamos = $query
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->cursorPaginate(30)
            ->appends($request->only(['q', 'estado', 'tipo']));

        return ReclamoAdminResource::collection($reclamos)
            ->additional(['meta' => ['total' => $total]]);
    }
}
