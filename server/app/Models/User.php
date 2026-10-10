<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

#[Fillable([
    'nombre',
    'apellido',
    'email',
    'password',
    'telefono',
    'dni',
])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'identidad_verificada_en' => 'datetime',
            'activo' => 'boolean',
            'password' => 'hashed',
        ];
    }

    public function cuadrilla(): BelongsTo
    {
        return $this->belongsTo(Cuadrilla::class, 'cuadrilla_id');
    }

    public function reclamos(): HasMany
    {
        return $this->hasMany(Reclamo::class, 'usuario_id');
    }

    public function reclamosAsignados(): HasMany
    {
        return $this->hasMany(Reclamo::class, 'empleado_id');
    }

    public function comentarios(): HasMany
    {
        return $this->hasMany(Comentario::class, 'usuario_id');
    }

    public function votos(): HasMany
    {
        return $this->hasMany(Voto::class, 'usuario_id');
    }

    public function historialEstadosReclamos(): HasMany
    {
        return $this->hasMany(HistorialEstadoReclamo::class, 'usuario_id');
    }
}
