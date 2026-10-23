<?php

namespace App\Http\Controllers;

use App\Http\Resources\UsuarioAdminResource;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class UsuarioController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $filtros = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'rol' => ['nullable', Rule::in(['ciudadano', 'empleado', 'admin'])],
            'estado' => ['nullable', Rule::in(['activa', 'inactiva'])],
            'cursor' => ['nullable', 'string'],
        ]);

        $query = User::query()
            ->select(['id', 'nombre', 'apellido', 'email', 'rol', 'activo']);

        $terminos = preg_split('/\s+/', trim($filtros['q'] ?? ''), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        foreach ($terminos as $termino) {
            $query->where(function (Builder $query) use ($termino): void {
                $busqueda = "%{$termino}%";
                $query->where('nombre', 'like', $busqueda)
                    ->orWhere('apellido', 'like', $busqueda)
                    ->orWhere('email', 'like', $busqueda);
            });
        }

        if (isset($filtros['rol'])) {
            $query->where('rol', $filtros['rol']);
        }

        if (isset($filtros['estado'])) {
            $query->where('activo', $filtros['estado'] === 'activa');
        }

        $total = (clone $query)->count();
        $usuarios = $query
            ->orderBy('apellido')
            ->orderBy('nombre')
            ->orderBy('id')
            ->cursorPaginate(30)
            ->appends($request->only(['q', 'rol', 'estado']));

        return UsuarioAdminResource::collection($usuarios)
            ->additional(['meta' => ['total' => $total]]);
    }
}
