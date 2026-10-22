<?php

namespace App\Http\Controllers;

use App\Models\Reclamo;
use App\Models\Voto;
use Illuminate\Http\Request;

class VotoController extends Controller
{
    public function store(Request $request, Reclamo $reclamo)
    {
        $validated = $request->validate([
            'valor' => 'required|in:confirma,desmiente',
        ]);

        $usuario = $request->user();

        // 1. Evitar que el creador vote en su propio reclamo
        if ((int) $reclamo->usuario_id === (int) $usuario->id) {
            return response()->json([
                'message' => 'No podés votar en tus propios reclamos.',
            ], 403);
        }

        // 2. Buscar si ya existía un voto previo
        $votoExistente = Voto::where('reclamo_id', $reclamo->id)
            ->where('usuario_id', $usuario->id)
            ->first();

        if ($votoExistente) {
            if ($votoExistente->valor === $validated['valor']) {
                // Si presiona el mismo botón que ya votó, borra el voto (lo cancela)
                $votoExistente->delete();
            } else {
                // Si presiona la opción contraria, actualiza el valor
                $votoExistente->valor = $validated['valor'];
                $votoExistente->save();
            }
        } else {
            // Si no tenía voto, crea un nuevo registro
            $voto = new Voto();
            $voto->reclamo_id = $reclamo->id;
            $voto->usuario_id = $usuario->id;
            $voto->valor = $validated['valor'];
            $voto->save();
        }

        // 3. Recalcular conteo
        $confirmaciones = Voto::where('reclamo_id', $reclamo->id)->where('valor', 'confirma')->count();
        $desmentidas = Voto::where('reclamo_id', $reclamo->id)->where('valor', 'desmiente')->count();

        return response()->json([
            'message' => 'Voto registrado correctamente',
            'confirmaciones' => $confirmaciones,
            'desmentidas' => $desmentidas,
        ]);
    }
}