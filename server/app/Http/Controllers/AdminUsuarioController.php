<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminUsuarioController extends Controller
{
    /**
     * Lista los usuarios ordenados de mayor a menor según sus sanciones activas vigentes,
     * ideal para el monitoreo de administración.
     */
    public function usuariosSancionados(Request $request): JsonResponse
    {
        // Usamos la relación 'sancionesActivas' que definimos previamente en el modelo User,
        // la cual cuenta solo las no revocadas cuya suspensión de 30 días sigue corriendo.
        $usuarios = User::withCount('sancionesActivas')
            ->has('sancionesActivas', '>', 0) // Solo los que tienen al menos 1 sanción activa
            ->orderByDesc('sanciones_activas_count') // Ordenados de mayor a menor (ej: 2, luego 1)
            ->get();

        return response()->json([
            'data' => $usuarios,
        ]);
    }
}
