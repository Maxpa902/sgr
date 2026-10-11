<?php

namespace App\Http\Controllers;

use App\Http\Requests\IniciarSesionRequest;
use App\Http\Resources\UsuarioResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class SesionController extends Controller
{
    /**
     * Valida las credenciales y emite un token nuevo para el dispositivo.
     */
    public function store(IniciarSesionRequest $request): JsonResponse
    {
        $usuario = User::where('email', $request->validated('email'))->first();

        if (! $usuario || ! Hash::check($request->validated('password'), $usuario->password)) {
            throw ValidationException::withMessages([
                'email' => 'El email o la contraseña no son correctos.',
            ]);
        }

        if (! $usuario->activo) {
            abort(Response::HTTP_FORBIDDEN, 'La cuenta está desactivada.');
        }

        $token = $usuario->createToken($request->validated('dispositivo') ?? 'app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'usuario' => new UsuarioResource($usuario),
        ]);
    }

    /**
     * Revoca solo el token con el que se hizo la petición; las otras sesiones siguen abiertas.
     */
    public function destroy(Request $request): Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }
}
