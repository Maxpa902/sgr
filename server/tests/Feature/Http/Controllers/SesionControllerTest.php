<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SesionControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_valid_credentials_return_a_token_for_the_user(): void
    {
        $usuario = User::factory()->create([
            'email' => 'ana@example.com',
            'rol' => 'admin',
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'ana@example.com',
            'password' => 'password',
        ]);

        $response->assertOk()
            ->assertJsonPath('usuario.id', $usuario->id)
            ->assertJsonPath('usuario.rol', 'admin')
            ->assertJsonStructure(['token']);
        $this->assertSame(1, $usuario->tokens()->count());
    }

    public function test_wrong_password_returns_422_without_issuing_a_token(): void
    {
        User::factory()->create(['email' => 'ana@example.com']);

        $this->postJson('/api/login', ['email' => 'ana@example.com', 'password' => 'incorrecta'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email' => 'El email o la contraseña no son correctos.']);

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_unknown_email_returns_the_same_422_as_a_wrong_password(): void
    {
        $this->postJson('/api/login', ['email' => 'nadie@example.com', 'password' => 'password'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email' => 'El email o la contraseña no son correctos.']);
    }

    public function test_deactivated_account_returns_403_without_issuing_a_token(): void
    {
        User::factory()->inactivo()->create(['email' => 'ana@example.com']);

        $this->postJson('/api/login', ['email' => 'ana@example.com', 'password' => 'password'])
            ->assertForbidden()
            ->assertJsonPath('message', 'La cuenta está desactivada.');

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_returns_429_after_five_failed_attempts(): void
    {
        User::factory()->create(['email' => 'ana@example.com']);
        $credenciales = ['email' => 'ana@example.com', 'password' => 'incorrecta'];

        for ($intento = 1; $intento <= 5; $intento++) {
            $this->postJson('/api/login', $credenciales)->assertUnprocessable();
        }

        $this->postJson('/api/login', $credenciales)->assertTooManyRequests();
    }

    public function test_logout_revokes_only_the_current_token_and_returns_204(): void
    {
        $usuario = User::factory()->create();
        $tokenDelCelular = $usuario->createToken('celular')->plainTextToken;
        $usuario->createToken('tablet');

        $this->withToken($tokenDelCelular)
            ->postJson('/api/logout')
            ->assertNoContent();

        $this->assertSame(['tablet'], $usuario->tokens()->pluck('name')->all());
    }

    public function test_logout_returns_401_when_no_token_is_provided(): void
    {
        $this->postJson('/api/logout')->assertUnauthorized();
    }
}
