<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ListadoCuentasTest extends TestCase
{
    use RefreshDatabase;

    public function test_personal_se_filtra_antes_de_paginar(): void
    {
        $admin = User::factory()->create(['rol' => 'admin', 'apellido' => 'Zeta']);
        $operario = User::factory()->create(['rol' => 'empleado', 'apellido' => 'Zeta']);
        User::factory()->count(35)->create(['rol' => 'ciudadano', 'apellido' => 'A']);

        $respuesta = $this->actingAs($admin)->getJson('/api/usuarios?rol=personal');

        $respuesta->assertOk()->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.total', 2)
            ->assertJsonFragment(['id' => $admin->id])
            ->assertJsonFragment(['id' => $operario->id]);
    }

    public function test_filtra_vecinos_por_suspension_vigente(): void
    {
        $admin = User::factory()->create(['rol' => 'admin']);
        $activo = User::factory()->create(['rol' => 'ciudadano', 'suspendido_hasta' => null]);
        $vencido = User::factory()->create(['rol' => 'ciudadano', 'suspendido_hasta' => now()->subDay()]);
        $suspendido = User::factory()->create(['rol' => 'ciudadano', 'suspendido_hasta' => now()->addDay()]);

        $this->actingAs($admin)->getJson('/api/usuarios?rol=ciudadano&suspension=activos')
            ->assertOk()->assertJsonCount(2, 'data')->assertJsonPath('meta.total', 2)
            ->assertJsonFragment(['id' => $activo->id])->assertJsonFragment(['id' => $vencido->id])
            ->assertJsonMissing(['id' => $suspendido->id]);
        $this->actingAs($admin)->getJson('/api/usuarios?rol=ciudadano&suspension=suspendidos')
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $suspendido->id)
            ->assertJsonPath('meta.total', 1)->assertJsonPath('data.0.suspendido_hasta', $suspendido->suspendido_hasta->toISOString());
    }
}
