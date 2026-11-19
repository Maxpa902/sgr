<?php

namespace App\Http\Controllers;

use App\Http\Resources\HistorialPublicoResource;
use App\Models\Reclamo;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Seguimiento público de un reclamo: sus cambios de estado, para cualquier usuario
 * con sesión. El personal ve el historial completo, con autores y observaciones
 * internas, en las vistas de trabajo y administración.
 */
class HistorialPublicoController extends Controller
{
    /**
     * Los cambios de estado del más viejo al más nuevo. Un reclamo dado de baja no
     * existe para esta ruta, y uno privado solo lo ve su creador.
     */
    public function index(Request $request, Reclamo $reclamo): AnonymousResourceCollection
    {
        abort_unless(
            $reclamo->es_publico || (int) $reclamo->usuario_id === (int) $request->user()->id,
            404,
        );

        $historial = $reclamo->historialEstados()
            ->with('estado')
            ->orderBy('created_at')
            ->orderBy('id')
            ->get();

        return HistorialPublicoResource::collection($historial);
    }
}
