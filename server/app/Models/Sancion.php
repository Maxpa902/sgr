<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Table;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Table('sanciones')]
#[Fillable([
    'usuario_id',
    'reclamo_id',
    'revocada_en',
    'revocada_por_id',
    'motivo_revocacion',
])]
class Sancion extends Model
{
    protected function casts(): array
    {
        return ['revocada_en' => 'datetime'];
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }

    public function reclamo(): BelongsTo
    {
        return $this->belongsTo(Reclamo::class, 'reclamo_id');
    }

    public function revocadaPor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'revocada_por_id');
    }
}
