<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable([
    'nombre',
    'apellido',
    'email',
    'password',
    'telefono',
    'dni',
    'rol',
    'activo',
])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

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
            'suspendido_hasta' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function reclamos(): HasMany
    {
        return $this->hasMany(Reclamo::class, 'usuario_id');
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

    public function sanciones(): HasMany
    {
        return $this->hasMany(Sancion::class, 'usuario_id');
    }
    public function sancionesActivas()
    {
        return $this->hasMany(Sancion::class, 'usuario_id')
            ->whereNull('revocada_en')
            ->where('created_at', '>', now()->subDays(180));
    }
}
