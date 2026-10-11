<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UsuarioActualControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_returns_401_when_no_token_is_provided(): void
    {
        $this->getJson('/api/usuario')->assertUnauthorized();
    }

    public function test_returns_the_authenticated_user_without_sensitive_fields(): void
    {
        $usuario = User::factory()->create(['dni' => '30111222']);
        Sanctum::actingAs($usuario);

        $this->getJson('/api/usuario')
            ->assertOk()
            ->assertJsonPath('data.id', $usuario->id)
            ->assertJsonPath('data.email', $usuario->email)
            ->assertJsonMissingPath('data.password')
            ->assertJsonMissingPath('data.dni');
    }

    public function test_deactivated_account_with_a_valid_token_returns_403(): void
    {
        $usuario = User::factory()->inactivo()->create();
        $token = $usuario->createToken('app')->plainTextToken;

        $this->withToken($token)
            ->getJson('/api/usuario')
            ->assertForbidden()
            ->assertJsonPath('message', 'La cuenta está desactivada.');
    }
}
