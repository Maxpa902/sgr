<?php

namespace App\Models;

use Database\Factories\TipoReclamoFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Table;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Table('tipos_reclamo')]
#[Fillable(['nombre', 'descripcion', 'activo'])]
class TipoReclamo extends Model
{
    /** @use HasFactory<TipoReclamoFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return ['activo' => 'boolean'];
    }

    public function reclamos(): HasMany
    {
        return $this->hasMany(Reclamo::class, 'tipo_reclamo_id');
    }
}
