<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\TestWith;
use Tests\TestCase;

class CrearCuentaInternaTest extends TestCase
{
    use RefreshDatabase;

    private function datos(): array
    {
        return ['nombre' => 'Ana', 'apellido' => 'Pérez', 'dni' => '30.111.222', 'email' => 'ana@example.com', 'password' => 'secreta123', 'password_confirmation' => 'secreta123', 'rol' => 'empleado'];
    }

    #[TestWith(['empleado'])]
    #[TestWith(['admin'])]
    public function test_admin_crea_cuenta_interna_sin_token(string $rol): void
    {
        $admin = User::factory()->create(['rol' => 'admin']);
        $response = $this->actingAs($admin)->postJson('/api/usuarios', [...$this->datos(), 'rol' => $rol, 'activo' => false]);
        $response->assertCreated()->assertJsonPath('data.rol', $rol)->assertJsonMissingPath('token');
        $this->assertDatabaseHas('users', ['email' => 'ana@example.com', 'dni' => '30111222', 'rol' => $rol, 'activo' => true]);
        $this->assertTrue(Hash::check('secreta123', User::where('email', 'ana@example.com')->firstOrFail()->password));
    }

    #[TestWith(['ciudadano'])]
    #[TestWith(['empleado'])]
    public function test_roles_no_admin_reciben_403(string $rol): void
    {
        $usuario = User::factory()->create(['rol' => $rol]);
        $this->actingAs($usuario)->postJson('/api/usuarios', $this->datos())->assertForbidden();
        $this->assertDatabaseMissing('users', ['email' => 'ana@example.com']);
    }

    public function test_sin_sesion_recibe_401(): void
    {
        $this->postJson('/api/usuarios', $this->datos())->assertUnauthorized();
        $this->assertDatabaseMissing('users', ['email' => 'ana@example.com']);
    }

    public function test_rechaza_rol_no_permitido_y_datos_duplicados(): void
    {
        $admin = User::factory()->create(['rol' => 'admin', 'email' => 'ana@example.com', 'dni' => '30111222']);
        $this->actingAs($admin)->postJson('/api/usuarios', [...$this->datos(), 'rol' => 'ciudadano'])
            ->assertUnprocessable()->assertJsonValidationErrors(['rol', 'dni', 'email']);
        $this->assertDatabaseCount('users', 1);
    }
}
