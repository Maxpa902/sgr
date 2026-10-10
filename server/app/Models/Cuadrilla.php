<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['nombre', 'activo'])]
class Cuadrilla extends Model
{
    protected function casts(): array
    {
        return ['activo' => 'boolean'];
    }

    public function empleados(): HasMany
    {
        return $this->hasMany(User::class, 'cuadrilla_id');
    }

    public function reclamos(): HasMany
    {
        return $this->hasMany(Reclamo::class, 'cuadrilla_id');
    }
}
