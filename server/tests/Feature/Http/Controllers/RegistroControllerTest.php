<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\TestWith;
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
            'dni' => '30111222',
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
            ->assertJsonMissingPath('usuario.dni');
        $this->assertDatabaseHas('users', [
            'email' => 'ana@example.com',
            'nombre' => 'Ana',
            'apellido' => 'Pérez',
            'dni' => '30111222',
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

    public function test_stores_dni_without_dots_spaces_or_dashes(): void
    {
        $this->postJson('/api/registro', [...$this->datosValidos(), 'dni' => '30.111.222'])
            ->assertCreated();

        $this->assertDatabaseHas('users', ['email' => 'ana@example.com', 'dni' => '30111222']);
    }

    public function test_rejects_already_registered_email_with_422(): void
    {
        User::factory()->create(['email' => 'ana@example.com']);

        $this->postJson('/api/registro', $this->datosValidos())
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email' => 'Ya existe una cuenta con ese email.']);

        $this->assertDatabaseCount('users', 1);
    }

    public function test_rejects_already_registered_dni_even_when_written_with_dots_with_422(): void
    {
        User::factory()->create(['dni' => '30111222']);

        $this->postJson('/api/registro', [...$this->datosValidos(), 'dni' => '30.111.222'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['dni' => 'Ya existe una cuenta con ese DNI.']);

        $this->assertDatabaseCount('users', 1);
    }

    #[TestWith(['123456'], 'too short')]
    #[TestWith(['123456789'], 'too long')]
    #[TestWith(['30111abc'], 'with letters')]
    public function test_rejects_dni_that_is_not_seven_or_eight_digits_with_422(string $dni): void
    {
        $this->postJson('/api/registro', [...$this->datosValidos(), 'dni' => $dni])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['dni' => 'El campo DNI debe tener entre 7 y 8 dígitos.']);
    }

    public function test_rejects_mismatched_password_confirmation_with_422(): void
    {
        $this->postJson('/api/registro', [...$this->datosValidos(), 'password_confirmation' => 'otra-cosa'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['password' => 'La confirmación de contraseña no coincide.']);
    }

    public function test_rejects_empty_payload_with_422_and_messages_in_spanish(): void
    {
        $this->postJson('/api/registro', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['nombre', 'apellido', 'dni', 'email', 'password'])
            ->assertJsonValidationErrors(['dni' => 'El campo DNI es obligatorio.'])
            ->assertJsonPath('message', 'El campo nombre es obligatorio. (y 4 errores más)');
    }
}
