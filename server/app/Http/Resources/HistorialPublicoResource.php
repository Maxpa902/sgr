<?php

namespace App\Http\Resources;

use App\Models\HistorialEstadoReclamo;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Un cambio de estado tal como lo ve cualquier vecino. No incluye quién lo hizo
 * (la app muestra "Cooperativa") y oculta el texto de las observaciones internas.
 *
 * @mixin HistorialEstadoReclamo
 */
class HistorialPublicoResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'estado' => $this->estado->nombre,
            'observacion' => $this->visibilidad === 'publica' ? $this->observacion : null,
            'creado_en' => $this->created_at->toIso8601String(),
        ];
    }
}
