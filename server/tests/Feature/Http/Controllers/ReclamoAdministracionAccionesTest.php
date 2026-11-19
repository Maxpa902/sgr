<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use App\Models\Sancion;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReclamoAdministracionAccionesTest extends TestCase
{
    use RefreshDatabase;

    public function test_solo_admin_desasigna_un_pendiente_asignado(): void
    {
        $admin = User::factory()->create(['rol' => 'admin']);
        $empleado = User::factory()->create(['rol' => 'empleado']);
        $reclamo = Reclamo::factory()->create();
        $reclamo->forceFill(['responsable_id' => $empleado->id, 'asignado_por_id' => $admin->id, 'asignado_en' => now()])->save();
        $url = "/api/reclamos/{$reclamo->id}/asignacion";

        Sanctum::actingAs($empleado);
        $this->deleteJson($url)->assertForbidden();
        Sanctum::actingAs($admin);
        $this->deleteJson($url)->assertOk()->assertJsonPath('data.responsable', null);
        $this->assertDatabaseHas('reclamos', ['id' => $reclamo->id, 'responsable_id' => null, 'asignado_por_id' => null, 'asignado_en' => null]);
        $this->deleteJson($url)->assertStatus(409);

        foreach (['en_proceso', 'resuelto', 'rechazado'] as $estado) {
            $cerrado = Reclamo::factory()->enEstado($estado)->create();
            $cerrado->forceFill(['responsable_id' => $empleado->id])->save();
            $this->deleteJson("/api/reclamos/{$cerrado->id}/asignacion")->assertStatus(409);
        }
    }

    public function test_rechazo_exige_motivo_y_guarda_historial_publico_solo_para_estados_activos(): void
    {
        EstadoReclamo::firstOrCreate(['nombre' => 'rechazado']);
        $admin = User::factory()->create(['rol' => 'admin']);
        $empleado = User::factory()->create(['rol' => 'empleado']);
        $reclamo = Reclamo::factory()->create();
        $url = "/api/reclamos/{$reclamo->id}/rechazar";
        Sanctum::actingAs($empleado);
        $this->postJson($url, ['observacion' => 'Motivo', 'es_falso' => false])->assertForbidden();
        Sanctum::actingAs($admin);
        $this->postJson($url, ['observacion' => ' ', 'es_falso' => false])->assertUnprocessable();
        $this->postJson($url, ['observacion' => 'Motivo'])->assertUnprocessable();
        $this->postJson($url, ['observacion' => 'No corresponde', 'es_falso' => false])
            ->assertOk()->assertJsonPath('data.estado', 'rechazado');
        $this->assertDatabaseHas('historial_estados_reclamos', [
            'reclamo_id' => $reclamo->id, 'usuario_id' => $admin->id,
            'observacion' => 'No corresponde', 'visibilidad' => 'publica',
        ]);
        $this->assertDatabaseCount('sanciones', 0);
        $this->getJson("/api/admin/reclamos/{$reclamo->id}")
            ->assertOk()
            ->assertJsonPath('data.cierre.observacion', 'No corresponde')
            ->assertJsonPath('data.cierre.autor.id', $admin->id);
        $this->postJson($url, ['observacion' => 'Otro', 'es_falso' => false])->assertStatus(409);

        $enProceso = Reclamo::factory()->enEstado('en_proceso')->create();
        $this->postJson("/api/reclamos/{$enProceso->id}/rechazar", ['observacion' => 'Motivo', 'es_falso' => false])->assertOk();
        $resuelto = Reclamo::factory()->enEstado('resuelto')->create();
        $this->postJson("/api/reclamos/{$resuelto->id}/rechazar", ['observacion' => 'Motivo', 'es_falso' => false])->assertStatus(409);
    }

    public function test_el_primer_rechazo_por_falso_sanciona_y_suspende_30_dias(): void
    {
        $this->travelTo('2026-11-19 12:00:00');
        EstadoReclamo::firstOrCreate(['nombre' => 'rechazado']);
        $creador = User::factory()->create(['rol' => 'ciudadano']);
        $reclamo = Reclamo::factory()->create(['usuario_id' => $creador->id]);
        Sanctum::actingAs(User::factory()->create(['rol' => 'admin']));

        $respuesta = $this->postJson("/api/reclamos/{$reclamo->id}/rechazar", ['observacion' => 'Es falso', 'es_falso' => true]);

        $respuesta->assertOk();
        $this->assertSame(1, Sancion::where('usuario_id', $creador->id)->where('reclamo_id', $reclamo->id)->count());
        $this->assertSame('2026-12-19 12:00:00', $creador->fresh()->suspendido_hasta->format('Y-m-d H:i:s'));
    }

    public function test_otro_rechazo_por_falso_durante_la_suspension_la_extiende_30_dias_desde_ese_rechazo(): void
    {
        $this->travelTo('2026-11-24 12:00:00');
        EstadoReclamo::firstOrCreate(['nombre' => 'rechazado']);
        $creador = User::factory()->create(['rol' => 'ciudadano', 'suspendido_hasta' => '2026-12-19 12:00:00']);
        $reclamo = Reclamo::factory()->create(['usuario_id' => $creador->id]);
        Sanctum::actingAs(User::factory()->create(['rol' => 'admin']));

        $respuesta = $this->postJson("/api/reclamos/{$reclamo->id}/rechazar", ['observacion' => 'Es falso', 'es_falso' => true]);

        $respuesta->assertOk();
        $this->assertSame('2026-12-24 12:00:00', $creador->fresh()->suspendido_hasta->format('Y-m-d H:i:s'));
    }
}
