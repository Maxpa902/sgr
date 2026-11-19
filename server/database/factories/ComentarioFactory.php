<?php

namespace Database\Factories;

use App\Models\Comentario;
use App\Models\Reclamo;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Comentario>
 */
class ComentarioFactory extends Factory
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
            'contenido' => fake()->sentence(),
        ];
    }
}
