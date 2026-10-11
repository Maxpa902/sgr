<?php

namespace App\Models;

use Database\Factories\VotoFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['reclamo_id', 'usuario_id', 'valor'])]
class Voto extends Model
{
    /** @use HasFactory<VotoFactory> */
    use HasFactory;

    public function reclamo(): BelongsTo
    {
        return $this->belongsTo(Reclamo::class, 'reclamo_id');
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }
}
