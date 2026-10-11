<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegistroControllerTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @return array<string, string>
     */
    private function datosValidos(): array
    {
        return [
            'nombre' => 'Ana',
            'apellido' => 'Pérez',
            'email' => 'ana@example.com',
            'password' => 'secreta123',
            'password_confirmation' => 'secreta123',
            'telefono' => '2974000000',
        ];
    }

    public function test_valid_payload_creates_citizen_and_returns_201_with_working_token(): void
    {
        $response = $this->postJson('/api/registro', $this->datosValidos());

        $response->assertCreated()
            ->assertJsonPath('usuario.email', 'ana@example.com')
            ->assertJsonPath('usuario.rol', 'ciudadano')
            ->assertJsonPath('usuario.estado_verificacion', 'no_solicitada');
        $this->assertDatabaseHas('users', [
            'email' => 'ana@example.com',
            'nombre' => 'Ana',
            'apellido' => 'Pérez',
            'rol' => 'ciudadano',
        ]);

        $this->withToken($response->json('token'))
            ->getJson('/api/usuario')
            ->assertOk()
            ->assertJsonPath('data.email', 'ana@example.com');
    }

    public function test_does_not_let_the_client_choose_its_role(): void
    {
        $this->postJson('/api/registro', [...$this->datosValidos(), 'rol' => 'admin'])
            ->assertCreated();

        $this->assertDatabaseHas('users', ['email' => 'ana@example.com', 'rol' => 'ciudadano']);
    }

    public function test_rejects_already_registered_email_with_422(): void
    {
        User::factory()->create(['email' => 'ana@example.com']);

        $this->postJson('/api/registro', $this->datosValidos())
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);

        $this->assertDatabaseCount('users', 1);
    }

    public function test_rejects_mismatched_password_confirmation_with_422(): void
    {
        $this->postJson('/api/registro', [...$this->datosValidos(), 'password_confirmation' => 'otra-cosa'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['password']);
    }

    public function test_rejects_empty_payload_with_422(): void
    {
        $this->postJson('/api/registro', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['nombre', 'apellido', 'email', 'password']);
    }
}
