<?php

namespace Tests\Feature;

use App\Models\Reclamo;
use App\Models\User;
use App\Models\Voto;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VotoControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_vecino_puede_votar_cambiar_quitar_y_volver_a_votar(): void
    {
        $reclamo = Reclamo::factory()->create();
        $usuario = User::factory()->create(['rol' => 'ciudadano']);
        Sanctum::actingAs($usuario);
        $url = "/api/reclamos/{$reclamo->id}/votar";

        $this->postJson($url, ['valor' => 'confirma'])->assertOk()->assertJsonPath('confirmaciones', 1);
        $this->getJson("/api/reclamos/{$reclamo->id}/votos")
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.valor', 'confirma')
            ->assertJsonPath('data.0.usuario', "{$usuario->nombre} {$usuario->apellido}");
        $this->postJson($url, ['valor' => 'desmiente'])->assertOk()
            ->assertJsonPath('confirmaciones', 0)->assertJsonPath('desmentidas', 1);
        $this->assertDatabaseCount('votos', 1);
        $this->postJson($url, ['valor' => 'desmiente'])->assertOk()->assertJsonPath('desmentidas', 0);
        $this->assertDatabaseCount('votos', 0);
        $this->postJson($url, ['valor' => 'confirma'])->assertOk()->assertJsonPath('confirmaciones', 1);
        $this->assertDatabaseCount('votos', 1);
    }

    public function test_no_se_pueden_modificar_votos_en_reclamos_finalizados_pero_si_consultarlos(): void
    {
        $usuario = User::factory()->create(['rol' => 'ciudadano']);
        Sanctum::actingAs($usuario);
        foreach (['resuelto', 'rechazado'] as $estado) {
            $reclamo = Reclamo::factory()->enEstado($estado)->create();
            Voto::factory()->create(['usuario_id' => $usuario->id, 'reclamo_id' => $reclamo->id]);
            $this->getJson("/api/reclamos/{$reclamo->id}/votos")->assertOk()->assertJsonCount(1, 'data');
            $this->postJson("/api/reclamos/{$reclamo->id}/votar", ['valor' => 'confirma'])->assertStatus(409);
            $this->postJson("/api/reclamos/{$reclamo->id}/votar", ['valor' => 'desmiente'])->assertStatus(409);
            $this->assertDatabaseHas('votos', ['usuario_id' => $usuario->id, 'reclamo_id' => $reclamo->id, 'valor' => 'confirma']);
        }
    }

    public function test_suspension_permite_consulta_pero_bloquea_cualquier_cambio_hasta_su_vencimiento(): void
    {
        $reclamo = Reclamo::factory()->enEstado('en_proceso')->create();
        $usuario = User::factory()->create(['rol' => 'empleado', 'suspendido_hasta' => now()->addDay()]);
        Voto::factory()->create(['reclamo_id' => $reclamo->id, 'usuario_id' => $usuario->id]);
        Sanctum::actingAs($usuario);
        $url = "/api/reclamos/{$reclamo->id}/votar";
        $this->getJson("/api/reclamos/{$reclamo->id}/votos")->assertOk()->assertJsonCount(1, 'data');
        $this->postJson($url, ['valor' => 'confirma'])->assertForbidden();
        $this->postJson($url, ['valor' => 'desmiente'])->assertForbidden();
        $this->assertDatabaseHas('votos', ['usuario_id' => $usuario->id, 'reclamo_id' => $reclamo->id, 'valor' => 'confirma']);
        $usuario->forceFill(['suspendido_hasta' => now()->subSecond()])->save();
        $this->postJson($url, ['valor' => 'desmiente'])->assertOk()->assertJsonPath('desmentidas', 1);
    }

    public function test_autorizacion_validacion_y_baja_logica(): void
    {
        $reclamo = Reclamo::factory()->create();
        $url = "/api/reclamos/{$reclamo->id}/votar";
        $this->postJson($url, ['valor' => 'confirma'])->assertUnauthorized();
        Sanctum::actingAs(User::findOrFail($reclamo->usuario_id));
        $this->postJson($url, ['valor' => 'confirma'])->assertForbidden();
        Sanctum::actingAs(User::factory()->create(['rol' => 'admin']));
        $this->postJson($url, ['valor' => 'confirma'])->assertForbidden();
        Sanctum::actingAs(User::factory()->inactivo()->create());
        $this->postJson($url, ['valor' => 'confirma'])->assertForbidden();
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));
        $this->postJson($url, ['valor' => 'otro'])->assertUnprocessable();
        $reclamo->delete();
        $this->getJson("/api/reclamos/{$reclamo->id}/votos")->assertNotFound();
        $this->postJson($url, ['valor' => 'confirma'])->assertNotFound();
        $this->assertDatabaseCount('votos', 0);
    }
}
