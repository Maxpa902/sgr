<?php

namespace App\Http\Controllers;

use App\Http\Requests\RegistrarUsuarioRequest;
use App\Http\Resources\UsuarioResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;

class RegistroController extends Controller
{
    /**
     * Crea una cuenta ciudadana y devuelve un token para usarla desde la app.
     */
    public function store(RegistrarUsuarioRequest $request): JsonResponse
    {
        $usuario = User::create(
            $request->safe()->only(['nombre', 'apellido', 'email', 'password', 'telefono'])
        )->refresh();

        $token = $usuario->createToken($request->validated('dispositivo') ?? 'app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'usuario' => new UsuarioResource($usuario),
        ], Response::HTTP_CREATED);
    }
}
