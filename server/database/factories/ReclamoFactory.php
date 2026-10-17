<?php

namespace Database\Factories;

use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use App\Models\TipoReclamo;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Reclamo>
 */
class ReclamoFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'usuario_id' => User::factory(),
            'tipo_reclamo_id' => TipoReclamo::factory(),
            'estado_id' => fn () => EstadoReclamo::firstOrCreate(['nombre' => 'pendiente'])->id,
            'titulo' => fake()->sentence(4),
            'descripcion' => fake()->paragraph(),
            'latitud' => fake()->latitude(-45.90, -45.82),
            'longitud' => fake()->longitude(-67.55, -67.45),
            'es_publico' => true,
        ];
    }

    /**
     * Put the claim in the given state of the state machine.
     */
    public function enEstado(string $nombre): static
    {
        return $this->state(fn (array $attributes) => [
            'estado_id' => EstadoReclamo::firstOrCreate(['nombre' => $nombre])->id,
        ]);
    }

    /**
     * Indicate that the citizen did not write a title, so the category is shown instead.
     */
    public function sinTitulo(): static
    {
        return $this->state(fn (array $attributes) => [
            'titulo' => null,
        ]);
    }

    /**
     * Indicate that only the creator and authorized staff can see the claim.
     */
    public function privado(): static
    {
        return $this->state(fn (array $attributes) => [
            'es_publico' => false,
        ]);
    }
}
