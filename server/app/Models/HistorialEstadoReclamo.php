<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Table;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Table('historial_estados_reclamos')]
#[Fillable([
    'reclamo_id',
    'estado_id',
    'usuario_id',
    'observacion',
    'visibilidad',
    'created_at',
])]
class HistorialEstadoReclamo extends Model
{
    public const UPDATED_AT = null;

    protected function casts(): array
    {
        return ['created_at' => 'datetime'];
    }

    public function reclamo(): BelongsTo
    {
        return $this->belongsTo(Reclamo::class, 'reclamo_id');
    }

    public function estado(): BelongsTo
    {
        return $this->belongsTo(EstadoReclamo::class, 'estado_id');
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }
}
