<?php

namespace App\Http\Controllers;

use App\Http\Requests\ActualizarPerfilRequest;
use App\Http\Resources\UsuarioResource;
use Illuminate\Http\Request;

class UsuarioActualController extends Controller
{
    public function show(Request $request): UsuarioResource
    {
        return new UsuarioResource($request->user());
    }

    public function update(ActualizarPerfilRequest $request): UsuarioResource
    {
        $usuario = $request->user();

        // Solo permitimos campos del perfil (nunca rol, activo ni suspendido_hasta)
        $datos = $request->safe()->only([
            'nombre',
            'apellido',
            'dni',
            'email',
            'telefono',
            'password',
        ]);

        $usuario->fill($datos);
        $usuario->save();

        return new UsuarioResource($usuario->refresh());
    }
}