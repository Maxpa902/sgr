<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReclamoTrabajoControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_tomar_y_comenzar_registra_transicion_una_vez(): void
    {
        EstadoReclamo::firstOrCreate(['nombre' => 'en_proceso']);
        $reclamo = Reclamo::factory()->create();
        $empleado = User::factory()->create(['rol' => 'empleado']);
        Sanctum::actingAs($empleado);
        $this->postJson("/api/reclamos/{$reclamo->id}/asignacion", ['responsable_id' => $empleado->id])
            ->assertOk()->assertJsonPath('data.estado', 'pendiente')->assertJsonPath('data.responsable.id', $empleado->id);
        $this->assertNotNull($reclamo->fresh()->asignado_en);
        $this->postJson("/api/reclamos/{$reclamo->id}/comenzar", ['observacion' => 'Inicio', 'visibilidad' => 'interna'])
            ->assertOk()->assertJsonPath('data.estado', 'en_proceso');
        $this->assertDatabaseHas('historial_estados_reclamos', ['reclamo_id' => $reclamo->id, 'usuario_id' => $empleado->id, 'observacion' => 'Inicio', 'visibilidad' => 'interna']);
        $this->postJson("/api/reclamos/{$reclamo->id}/comenzar")->assertStatus(409);
        $this->assertDatabaseCount('historial_estados_reclamos', 1);
    }

    public function test_admin_puede_asignar_y_reasignar_pendiente(): void
    {
        $reclamo = Reclamo::factory()->create();
        $admin = User::factory()->create(['rol' => 'admin']);
        $empleado = User::factory()->create(['rol' => 'empleado']);
        Sanctum::actingAs($admin);
        $url = "/api/reclamos/{$reclamo->id}/asignacion";
        $this->postJson($url, ['responsable_id' => $empleado->id])->assertOk();
        $this->postJson($url, ['responsable_id' => $admin->id])->assertOk()->assertJsonPath('data.responsable.id', $admin->id);
        $this->assertSame($admin->id, $reclamo->fresh()->asignado_por_id);
        $this->getJson("/api/reclamos/{$reclamo->id}/trabajo")->assertOk()->assertJsonPath('data.responsable.id', $admin->id);
    }

    public function test_solo_responsable_puede_comenzar_y_empleado_no_puede_tomar_uno_ocupado(): void
    {
        EstadoReclamo::firstOrCreate(['nombre' => 'en_proceso']);
        $reclamo = Reclamo::factory()->create();
        $uno = User::factory()->create(['rol' => 'empleado']);
        $otro = User::factory()->create(['rol' => 'empleado']);
        $url = "/api/reclamos/{$reclamo->id}/asignacion";
        Sanctum::actingAs($uno);
        $this->postJson("/api/reclamos/{$reclamo->id}/comenzar")->assertStatus(409);
        $this->postJson($url, ['responsable_id' => $otro->id])->assertForbidden();
        $this->postJson($url, ['responsable_id' => $uno->id])->assertOk();
        Sanctum::actingAs($otro);
        $this->postJson($url, ['responsable_id' => $otro->id])->assertStatus(409);
        $this->postJson("/api/reclamos/{$reclamo->id}/comenzar")->assertStatus(409);
        Sanctum::actingAs($uno);
        $this->postJson("/api/reclamos/{$reclamo->id}/comenzar")->assertOk();
        $admin = User::factory()->create(['rol' => 'admin']);
        Sanctum::actingAs($admin);
        $this->postJson($url, ['responsable_id' => $admin->id])->assertStatus(409);
    }

    public function test_autorizacion_y_destinatarios(): void
    {
        $reclamo = Reclamo::factory()->create();
        $url = "/api/reclamos/{$reclamo->id}/asignacion";
        $this->postJson($url, [])->assertUnauthorized();
        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        Sanctum::actingAs($vecino);
        $this->postJson($url, ['responsable_id' => $vecino->id])->assertForbidden();
        $admin = User::factory()->create(['rol' => 'admin']);
        $inactivo = User::factory()->inactivo()->create(['rol' => 'empleado']);
        Sanctum::actingAs($admin);
        $this->postJson($url, ['responsable_id' => $vecino->id])->assertStatus(422);
        $this->postJson($url, ['responsable_id' => $inactivo->id])->assertStatus(422);
        $reclamo->delete();
        $this->postJson($url, ['responsable_id' => $admin->id])->assertNotFound();
    }

    public function test_estados_finales_no_admiten_asignacion_ni_inicio(): void
    {
        $admin = User::factory()->create(['rol' => 'admin']);
        EstadoReclamo::firstOrCreate(['nombre' => 'pendiente']);
        EstadoReclamo::firstOrCreate(['nombre' => 'en_proceso']);
        Sanctum::actingAs($admin);

        foreach (['resuelto', 'rechazado'] as $estado) {
            $reclamo = Reclamo::factory()->enEstado($estado)->create();
            $this->postJson("/api/reclamos/{$reclamo->id}/asignacion", ['responsable_id' => $admin->id])->assertStatus(409);
            $this->postJson("/api/reclamos/{$reclamo->id}/comenzar")->assertStatus(409);
        }
        $this->assertDatabaseCount('historial_estados_reclamos', 0);
    }
    public function test_finalizar_requiere_responsable_y_registra_historial_una_vez(): void
    {
        $empleado = User::factory()->create(['rol' => 'empleado']);
        $otro = User::factory()->create(['rol' => 'empleado']);
        EstadoReclamo::firstOrCreate(['nombre' => 'resuelto']);
        $reclamo = Reclamo::factory()->enEstado('en_proceso')->create(['responsable_id' => $empleado->id]);
        $url = "/api/reclamos/{$reclamo->id}/finalizar";
        Sanctum::actingAs($otro);
        $this->postJson($url, ['observacion' => 'Terminado'])->assertStatus(409);
        Sanctum::actingAs($empleado);
        $this->postJson($url, ['observacion' => ''])->assertUnprocessable();
        $this->postJson($url, ['observacion' => 'Terminado', 'visibilidad' => 'interna'])->assertOk()->assertJsonPath('data.estado', 'resuelto');
        $this->assertDatabaseHas('historial_estados_reclamos', ['reclamo_id' => $reclamo->id, 'usuario_id' => $empleado->id, 'observacion' => 'Terminado', 'visibilidad' => 'interna']);
        $this->postJson($url, ['observacion' => 'Otra vez'])->assertStatus(409);
        $this->assertDatabaseCount('historial_estados_reclamos', 1);
    }

    public function test_operario_rechaza_solo_falso_y_asignado(): void
    {
        $empleado = User::factory()->create(['rol' => 'empleado']);
        $otro = User::factory()->create(['rol' => 'empleado']);
        EstadoReclamo::firstOrCreate(['nombre' => 'rechazado']);
        $reclamo = Reclamo::factory()->create(['responsable_id' => $empleado->id]);
        $url = "/api/reclamos/{$reclamo->id}/rechazar";
        Sanctum::actingAs($otro);
        $this->postJson($url, ['observacion' => 'Falso', 'es_falso' => true])->assertStatus(409);
        Sanctum::actingAs($empleado);
        $this->postJson($url, ['observacion' => 'Otro motivo', 'es_falso' => false])->assertForbidden();
        $this->postJson($url, ['observacion' => 'Falso', 'es_falso' => true])->assertOk();
        $this->postJson($url, ['observacion' => 'Falso', 'es_falso' => true])->assertStatus(409);
        $this->assertDatabaseCount('sanciones', 1);
        $this->assertDatabaseHas('historial_estados_reclamos', ['reclamo_id' => $reclamo->id, 'observacion' => 'Falso', 'visibilidad' => 'publica']);
    }

}
