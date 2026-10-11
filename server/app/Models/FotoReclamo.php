<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Table;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Table('fotos_reclamo')]
#[Fillable(['reclamo_id', 'ruta'])]
class FotoReclamo extends Model
{
    public function reclamo(): BelongsTo
    {
        return $this->belongsTo(Reclamo::class, 'reclamo_id');
    }
}
