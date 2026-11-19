<?php

namespace App\Http\Resources;

use App\Models\Sancion;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Una sanción vista por el admin: qué reclamo falso la causó, hasta cuándo
 * suspende al vecino y, si fue revocada, quién lo hizo y por qué.
 *
 * @mixin Sancion
 */
class SancionResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reclamo' => $this->reclamo ? [
                'id' => $this->reclamo->id,
                'titulo' => $this->reclamo->titulo_visible,
            ] : null,
            'activa' => $this->estaActiva(),
            'creada_en' => $this->created_at->toIso8601String(),
            'termina_en' => $this->terminaEn()->toIso8601String(),
            'revocada_en' => $this->revocada_en?->toIso8601String(),
            'revocada_por' => $this->revocadaPor ? [
                'id' => $this->revocadaPor->id,
                'nombre' => $this->revocadaPor->nombre,
                'apellido' => $this->revocadaPor->apellido,
            ] : null,
            'motivo_revocacion' => $this->motivo_revocacion,
        ];
    }
}
