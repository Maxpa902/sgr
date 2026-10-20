<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class UsuarioDemoSeeder extends Seeder
{
    /**
     * Create the accounts used to develop the admin and employee views.
     */
    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])) {
            return;
        }

        $usuarios = [
            [
                'nombre' => 'Admin',
                'apellido' => 'SGR',
                'email' => 'admin@sgr.local',
                'rol' => 'admin',
            ],
            [
                'nombre' => 'Empleado',
                'apellido' => 'SGR',
                'email' => 'empleado@sgr.local',
                'rol' => 'empleado',
            ],
        ];

        foreach ($usuarios as $datos) {
            $usuario = User::firstOrNew(['email' => $datos['email']]);

            $usuario->fill([
                'nombre' => $datos['nombre'],
                'apellido' => $datos['apellido'],
                'dni' => null,
                'telefono' => null,
            ]);
            if (! $usuario->exists) {
                $usuario->password = 'password';
            }

            $usuario->forceFill([
                'rol' => $datos['rol'],
                'activo' => true,
            ]);

            if ($usuario->isDirty()) {
                $usuario->save();
            }
        }
    }
}
