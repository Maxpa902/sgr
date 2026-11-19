<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EditarPerfilTest extends TestCase
{
    use RefreshDatabase;

    public function test_usuario_puede_editar_sus_datos_personales_y_normaliza_dni(): void
    {
        $usuario = $this->crearUsuario([
            'nombre' => 'Juan',
            'apellido' => 'Pérez',
            'dni' => '35123456',
            'email' => 'juan@example.com',
            'telefono' => null,
        ]);

        Sanctum::actingAs($usuario);

        $response = $this->putJson('/api/usuario', [
            'nombre' => 'Juan Carlos',
            'apellido' => 'Gómez',
            'dni' => '35.987.654',
            'telefono' => '2974112233',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.nombre', 'Juan Carlos')
            ->assertJsonPath('data.apellido', 'Gómez')
            ->assertJsonPath('data.telefono', '2974112233');

        $this->assertDatabaseHas('users', [
            'id' => $usuario->id,
            'nombre' => 'Juan Carlos',
            'apellido' => 'Gómez',
            'dni' => '35987654',
            'telefono' => '2974112233',
        ]);
    }

    public function test_puede_guardar_mismo_email_y_dni_propios_sin_error_de_unicidad(): void
    {
        $usuario = $this->crearUsuario([
            'dni' => '34111222',
            'email' => 'propio@example.com',
        ]);

        Sanctum::actingAs($usuario);

        $this->putJson('/api/usuario', [
            'nombre' => 'Nombre Actualizado',
            'apellido' => $usuario->apellido,
            'dni' => '34.111.222',
            'email' => 'propio@example.com',
        ])->assertOk();
    }

    public function test_no_permite_usar_email_o_dni_de_otro_usuario(): void
    {
        $otroUsuario = $this->crearUsuario([
            'dni' => '33111222',
            'email' => 'ocupado@example.com',
        ]);

        $usuario = $this->crearUsuario([
            'dni' => '34555666',
            'email' => 'libre@example.com',
        ]);

        Sanctum::actingAs($usuario);

        $this->putJson('/api/usuario', [
            'email' => $otroUsuario->email,
            'dni' => $otroUsuario->dni,
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['email', 'dni']);
    }

    public function test_usuario_puede_cambiar_su_contrasena_validando_la_actual(): void
    {
        $usuario = $this->crearUsuario([
            'password' => 'ClaveVieja123',
        ]);

        Sanctum::actingAs($usuario);

        // Si la contraseña actual es incorrecta, debe rechazar con 422
        $this->putJson('/api/usuario', [
            'password_actual' => 'ClaveIncorrecta',
            'password' => 'ClaveNueva123',
            'password_confirmation' => 'ClaveNueva123',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['password_actual']);

        // Con la contraseña actual correcta, actualiza el hash
        $this->putJson('/api/usuario', [
            'password_actual' => 'ClaveVieja123',
            'password' => 'ClaveNueva123',
            'password_confirmation' => 'ClaveNueva123',
        ])->assertOk();

        $usuario->refresh();
        $this->assertTrue(Hash::check('ClaveNueva123', $usuario->password));
    }

    public function test_edicion_de_perfil_ignora_intentos_de_cambiar_rol_o_estado_activo(): void
    {
        $vecino = $this->crearUsuario([
            'rol' => 'ciudadano',
            'activo' => true,
        ]);

        Sanctum::actingAs($vecino);

        $this->putJson('/api/usuario', [
            'nombre' => 'Vecino Vivo',
            'rol' => 'admin',
            'activo' => false,
        ])->assertOk();

        $this->assertDatabaseHas('users', [
            'id' => $vecino->id,
            'nombre' => 'Vecino Vivo',
            'rol' => 'ciudadano',
            'activo' => 1,
        ]);
    }

    public function test_cuenta_desactivada_no_puede_editar_su_perfil(): void
    {
        $usuario = $this->crearUsuario([
            'activo' => false,
        ]);

        Sanctum::actingAs($usuario);

        $this->putJson('/api/usuario', [
            'nombre' => 'Intento Desactivado',
        ])->assertForbidden();
    }

    private function crearUsuario(array $overrides = []): User
    {
        static $contador = 1;
        $numero = $contador++;

        return User::forceCreate(array_merge([
            'nombre' => "Usuario {$numero}",
            'apellido' => 'Test',
            'email' => "perfil{$numero}@example.com",
            'password' => 'Password123',
            'dni' => str_pad((string) (32000000 + $numero), 8, '0', STR_PAD_LEFT),
            'rol' => 'ciudadano',
            'activo' => true,
        ], $overrides));
    }
}