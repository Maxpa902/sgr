<?php

namespace App\Http\Resources;

use App\Models\Comentario;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Un comentario de un reclamo. `es_mio` le dice a la app si puede ofrecer
 * editarlo o borrarlo; el server igual lo vuelve a comprobar.
 *
 * @mixin Comentario
 */
class ComentarioResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'contenido' => $this->contenido,
            'autor' => $this->usuario
                ? trim("{$this->usuario->nombre} {$this->usuario->apellido}")
                : 'Usuario',
            'es_mio' => (int) $this->usuario_id === (int) $request->user()?->id,
            'editado' => $this->updated_at->gt($this->created_at),
            'creado_en' => $this->created_at->toIso8601String(),
        ];
    }
}
