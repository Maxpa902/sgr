<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Table;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

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
    /** Días de suspensión que genera cada reclamo rechazado por falso. */
    public const DIAS_SUSPENSION = 30;

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

    /** Fecha en que termina la suspensión que generó esta sanción. */
    public function terminaEn(): Carbon
    {
        return $this->created_at->copy()->addDays(self::DIAS_SUSPENSION);
    }

    /** Activa: no fue revocada y su suspensión todavía no terminó. */
    public function estaActiva(): bool
    {
        return $this->revocada_en === null && $this->terminaEn()->isFuture();
    }
}
