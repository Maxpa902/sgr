<?php

namespace App\Models;

use Database\Factories\ComentarioFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['reclamo_id', 'usuario_id', 'contenido'])]
class Comentario extends Model
{
    /** @use HasFactory<ComentarioFactory> */
    use HasFactory;

    /** Comentarios que cada usuario puede tener a la vez en un mismo reclamo. */
    public const LIMITE_POR_USUARIO = 3;

    public function reclamo(): BelongsTo
    {
        return $this->belongsTo(Reclamo::class, 'reclamo_id');
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }
}
