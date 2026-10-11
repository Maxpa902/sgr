<?php

namespace Database\Factories;

use App\Models\Reclamo;
use App\Models\User;
use App\Models\Voto;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Voto>
 */
class VotoFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'reclamo_id' => Reclamo::factory(),
            'usuario_id' => User::factory(),
            'valor' => 'confirma',
        ];
    }

    /**
     * Indicate that the voter says the problem is not real.
     */
    public function desmiente(): static
    {
        return $this->state(fn (array $attributes) => [
            'valor' => 'desmiente',
        ]);
    }
}
