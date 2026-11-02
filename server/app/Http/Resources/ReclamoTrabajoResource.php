<?php

namespace App\Http\Resources;

use App\Models\Reclamo;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Reclamo */
class ReclamoTrabajoResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'titulo' => $this->titulo_visible,
            'descripcion' => $this->descripcion,
            'direccion' => $this->direccion,
            'tipo' => $this->tipoReclamo->nombre,
            'tipo_icono' => $this->tipoReclamo->icono,
            'estado' => $this->estado->nombre,
            'latitud' => (float) $this->latitud,
            'longitud' => (float) $this->longitud,
            'creado_en' => $this->created_at->toIso8601String(),
        ];
    }
}
