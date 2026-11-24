<?php

namespace App\Http\Controllers;

use App\Http\Requests\CrearCuentaInternaRequest;
use App\Http\Resources\UsuarioAdminResource;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Validation\Rule;

class UsuarioController extends Controller
{
    public function store(CrearCuentaInternaRequest $request): JsonResponse
    {
        $usuario = new User($request->safe()->only(['nombre', 'apellido', 'dni', 'email', 'password', 'telefono']));
        $usuario->rol = $request->validated('rol');
        $usuario->save();

        return (new UsuarioAdminResource($usuario->refresh()))
            ->response()->setStatusCode(Response::HTTP_CREATED);
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $filtros = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'rol' => ['nullable', Rule::in(['ciudadano', 'empleado', 'admin', 'personal'])],
            'estado' => ['nullable', Rule::in(['activa', 'inactiva'])],
            'suspension' => ['nullable', Rule::in(['activos', 'suspendidos'])],
            'cursor' => ['nullable', 'string'],
        ]);

        $query = User::query()
            ->select(['id', 'nombre', 'apellido', 'email', 'rol', 'activo', 'suspendido_hasta']);

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
            if ($filtros['rol'] === 'personal') {
                $query->whereIn('rol', ['admin', 'empleado']);
            } else {
                $query->where('rol', $filtros['rol']);
            }
        }

        if (isset($filtros['estado'])) {
            $query->where('activo', $filtros['estado'] === 'activa');
        }

        if (($filtros['suspension'] ?? null) === 'suspendidos') {
            $query->where('suspendido_hasta', '>', now());
        } elseif (($filtros['suspension'] ?? null) === 'activos') {
            $query->where(fn (Builder $query) => $query
                ->whereNull('suspendido_hasta')
                ->orWhere('suspendido_hasta', '<=', now()));
        }

        $total = (clone $query)->count();
        $usuarios = $query
            ->orderBy('apellido')
            ->orderBy('nombre')
            ->orderBy('id')
            ->cursorPaginate(30)
            ->appends($request->only(['q', 'rol', 'estado', 'suspension']));

        return UsuarioAdminResource::collection($usuarios)
            ->additional(['meta' => ['total' => $total]]);
    }
}
