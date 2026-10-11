<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Table;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Table('estados_reclamo')]
#[Fillable(['nombre'])]
class EstadoReclamo extends Model
{
    /**
     * Estados en los que un reclamo sigue abierto y cuenta como activo.
     *
     * @var list<string>
     */
    public const ACTIVOS = ['pendiente', 'en_proceso'];

    public function reclamos(): HasMany
    {
        return $this->hasMany(Reclamo::class, 'estado_id');
    }

    public function historial(): HasMany
    {
        return $this->hasMany(HistorialEstadoReclamo::class, 'estado_id');
    }
}
