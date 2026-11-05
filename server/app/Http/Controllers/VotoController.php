<?php

namespace App\Http\Controllers;

use App\Models\Reclamo;
use App\Models\User;
use App\Models\Voto;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class VotoController extends Controller
{
    public function index(Reclamo $reclamo): JsonResponse
    {
        $votos = Voto::where('reclamo_id', $reclamo->id)
            ->with('usuario:id,nombre,apellido')
            ->get(['id', 'usuario_id', 'valor', 'created_at']);

        return response()->json([
            'data' => $votos->map(function ($voto) {
                return [
                    'id' => $voto->id,
                    'usuario' => $voto->usuario ? trim("{$voto->usuario->nombre} {$voto->usuario->apellido}") : 'Usuario',
                    'valor' => $voto->valor,
                    'creado_en' => $voto->created_at->toIso8601String(),
                ];
            }),
        ]);
    }

    public function store(Request $request, Reclamo $reclamo): JsonResponse
    {
        $validated = $request->validate([
            'valor' => 'required|in:confirma,desmiente',
        ]);

        return DB::transaction(function () use ($request, $reclamo, $validated): JsonResponse {
            // Serializar con transiciones y otros votos antes de comprobar el estado.
            $reclamo = Reclamo::whereKey($reclamo->id)->lockForUpdate()->firstOrFail();
            $usuario = User::whereKey($request->user()->id)->lockForUpdate()->firstOrFail();

            if ($usuario->suspendido_hasta?->isFuture()) {
                return response()->json(['message' => 'Tu cuenta está suspendida y no puede votar.'], 403);
            }

            if ((int) $reclamo->usuario_id === (int) $usuario->id) {
                return response()->json(['message' => 'No podés votar en tus propios reclamos.'], 403);
            }

            if (! in_array($reclamo->estado->nombre, ['pendiente', 'en_proceso'], true)) {
                return response()->json(['message' => 'No se puede votar en un reclamo finalizado.'], 409);
            }

            $voto = Voto::where('reclamo_id', $reclamo->id)
                ->where('usuario_id', $usuario->id)
                ->first();

            if ($voto && $voto->valor === $validated['valor']) {
                $voto->delete();
            } elseif ($voto) {
                $voto->update(['valor' => $validated['valor']]);
            } else {
                Voto::create([
                    'reclamo_id' => $reclamo->id,
                    'usuario_id' => $usuario->id,
                    'valor' => $validated['valor'],
                ]);
            }

            return response()->json([
                'message' => 'Voto registrado correctamente',
                'confirmaciones' => $reclamo->votos()->where('valor', 'confirma')->count(),
                'desmentidas' => $reclamo->votos()->where('valor', 'desmiente')->count(),
            ]);
        });
    }
}
