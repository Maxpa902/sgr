<?php

namespace App\Http\Resources;

use App\Models\Reclamo;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Datos mínimos de un reclamo para dibujar su pin en el mapa.
 *
 * @mixin Reclamo
 */
class ReclamoMapaResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'titulo' => $this->titulo_visible,
            'latitud' => (float) $this->latitud,
            'longitud' => (float) $this->longitud,
            'tipo' => new TipoReclamoResource($this->whenLoaded('tipoReclamo')),
            'estado' => $this->estado->nombre,
            'confirmaciones' => $this->confirmaciones_count,
            'desmentidas' => $this->desmentidas_count,
            'created_at' => $this->created_at,
        ];
    }
}
