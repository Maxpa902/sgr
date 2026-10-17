<?php

namespace App\Models;

use Database\Factories\ReclamoFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Scope;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'usuario_id',
    'tipo_reclamo_id',
    'estado_id',
    'titulo',
    'descripcion',
    'latitud',
    'longitud',
    'direccion',
    'es_publico',
])]
class Reclamo extends Model
{
    /** @use HasFactory<ReclamoFactory> */
    use HasFactory, SoftDeletes;

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

    public function fotos(): HasMany
    {
        return $this->hasMany(FotoReclamo::class, 'reclamo_id');
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

    public function sancion(): HasOne
    {
        return $this->hasOne(Sancion::class, 'reclamo_id');
    }

    /**
     * Título para mostrar: el que escribió el vecino o, si no escribió ninguno, la categoría.
     */
    protected function tituloVisible(): Attribute
    {
        return Attribute::get(fn (): string => $this->titulo ?? $this->tipoReclamo->nombre);
    }

    #[Scope]
    protected function publicos(Builder $query): void
    {
        $query->where('es_publico', true);
    }
}
