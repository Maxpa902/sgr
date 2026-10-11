<?php

namespace Database\Factories;

use App\Models\TipoReclamo;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<TipoReclamo>
 */
class TipoReclamoFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'nombre' => fake()->unique()->words(2, true),
            'descripcion' => fake()->sentence(),
            'activo' => true,
        ];
    }

    /**
     * Indicate that the category is no longer offered for new claims.
     */
    public function inactivo(): static
    {
        return $this->state(fn (array $attributes) => [
            'activo' => false,
        ]);
    }
}
