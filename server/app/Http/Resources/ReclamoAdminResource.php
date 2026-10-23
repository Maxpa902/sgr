<?php

namespace App\Http\Resources;

use App\Models\Reclamo;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Reclamo */
class ReclamoAdminResource extends JsonResource
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
            'estado' => $this->estado->nombre,
            'creador' => trim("{$this->usuario->nombre} {$this->usuario->apellido}"),
            'email_creador' => $this->usuario->email,
            'creado_en' => $this->created_at->toIso8601String(),
        ];
    }
}
