<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AdminCuentaController extends Controller
{
    /**
     * Actualiza el estado o rol de una cuenta de usuario con validaciones de seguridad.
     */
    public function actualizar(Request $request, User $user): JsonResponse
    {
        $actor = $request->user();

        $datos = $request->validate([
            'activo' => ['required', 'boolean'],
        ]);

        if (!in_array($user->rol, ['empleado', 'admin'], true)) {
            return response()->json([
                'message' => 'Solo se pueden activar o desactivar cuentas de operarios y administradores.',
            ], 422);
        }

        if (!$datos['activo'] && $user->id === $actor->id) {
            return response()->json([
                'message' => 'No podés desactivar tu propia cuenta de administrador.',
            ], 422);
        }

        if (!$datos['activo'] && $user->rol === 'admin') {
            $adminsActivos = User::where('rol', 'admin')
                ->where('activo', true)
                ->where('id', '<>', $user->id)
                ->count();
            if ($adminsActivos === 0) {
                return response()->json([
                    'message' => 'No se puede desactivar al último administrador activo del sistema.',
                ], 422);
            }
        }

        $user->update($datos);

        return response()->json([
            'message' => 'Cuenta actualizada correctamente.',
            'data' => $user->fresh(),
        ]);
    }
}
