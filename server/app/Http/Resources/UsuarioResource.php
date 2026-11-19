<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
class UsuarioResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nombre' => $this->nombre,
            'apellido' => $this->apellido,
            'email' => $this->email,
            'telefono' => $this->telefono,
            'rol' => $this->rol,
            'suspendido_hasta' => $this->suspendido_hasta,
            'sanciones_activas' => $this->sanciones_activas_count
                ?? $this->sancionesActivas()->count(),
        ];
    }
}
