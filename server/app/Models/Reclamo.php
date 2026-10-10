<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Scope;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'usuario_id',
    'tipo_reclamo_id',
    'estado_id',
    'empleado_id',
    'cuadrilla_id',
    'titulo',
    'descripcion',
    'foto',
    'latitud',
    'longitud',
    'direccion',
    'es_publico',
])]
class Reclamo extends Model
{
    use SoftDeletes;

    protected function casts(): array
    {
        return [
            'latitud' => 'decimal:7',
            'longitud' => 'decimal:7',
            'es_publico' => 'boolean',
        ];
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }

    public function tipoReclamo(): BelongsTo
    {
        return $this->belongsTo(TipoReclamo::class, 'tipo_reclamo_id');
    }

    public function estado(): BelongsTo
    {
        return $this->belongsTo(EstadoReclamo::class, 'estado_id');
    }

    public function empleado(): BelongsTo
    {
        return $this->belongsTo(User::class, 'empleado_id');
    }

    public function cuadrilla(): BelongsTo
    {
        return $this->belongsTo(Cuadrilla::class, 'cuadrilla_id');
    }

    public function comentarios(): HasMany
    {
        return $this->hasMany(Comentario::class, 'reclamo_id');
    }

    public function votos(): HasMany
    {
        return $this->hasMany(Voto::class, 'reclamo_id');
    }

    public function historialEstados(): HasMany
    {
        return $this->hasMany(HistorialEstadoReclamo::class, 'reclamo_id');
    }

    #[Scope]
    protected function publicos(Builder $query): void
    {
        $query->where('es_publico', true);
    }
}
