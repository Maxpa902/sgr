<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use App\Models\TipoReclamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SeguimientoReclamoTest extends TestCase
{
    use RefreshDatabase;

    public function test_se_registra_la_creacion_una_sola_vez(): void
    {
        $pendiente = EstadoReclamo::firstOrCreate(['nombre' => 'pendiente']);
        $tipo = TipoReclamo::factory()->create();
        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        Sanctum::actingAs($vecino);
        $respuesta = $this->postJson('/api/reclamos', [
            'titulo' => 'Problema', 'descripcion' => 'Detalle',
            'tipo_reclamo_id' => $tipo->id, 'latitud' => -45.8,
            'longitud' => -67.5, 'direccion' => 'Calle 123',
            'forzar_creacion' => true,
        ])->assertCreated();
        $id = $respuesta->json('data.id');
        $this->assertDatabaseHas('historial_estados_reclamos', [
            'reclamo_id' => $id, 'estado_id' => $pendiente->id,
            'usuario_id' => $vecino->id, 'visibilidad' => 'publica',
        ]);
        $this->assertSame(1, Reclamo::findOrFail($id)->historialEstados()->count());
    }

    public function test_detalle_admin_expone_historial_real_ordenado_y_observaciones_internas(): void
    {
        $reclamo = Reclamo::factory()->create();
        $admin = User::factory()->create(['rol' => 'admin']);
        $enProceso = EstadoReclamo::firstOrCreate(['nombre' => 'en_proceso']);
        $fecha = now()->subDay();
        $primero = $reclamo->historialEstados()->create([
            'estado_id' => $reclamo->estado_id, 'usuario_id' => $reclamo->usuario_id,
            'visibilidad' => 'publica', 'created_at' => $fecha,
        ]);
        $segundo = $reclamo->historialEstados()->create([
            'estado_id' => $enProceso->id, 'usuario_id' => $admin->id,
            'observacion' => 'Nota interna', 'visibilidad' => 'interna', 'created_at' => $fecha,
        ]);
        Sanctum::actingAs($admin);
        $url = "/api/admin/reclamos/{$reclamo->id}";
        $this->getJson($url)->assertOk()
            ->assertJsonCount(2, 'data.historial')
            ->assertJsonPath('data.historial.0.id', $primero->id)
            ->assertJsonPath('data.historial.1.id', $segundo->id)
            ->assertJsonPath('data.historial.1.estado', 'en_proceso')
            ->assertJsonPath('data.historial.1.autor.id', $admin->id)
            ->assertJsonPath('data.historial.1.observacion', 'Nota interna')
            ->assertJsonPath('data.historial.1.visibilidad', 'interna');
        $antiguo = Reclamo::factory()->create();
        $this->getJson("/api/admin/reclamos/{$antiguo->id}")->assertOk()
            ->assertJsonCount(0, 'data.historial');
    }

    public function test_asignacion_actual_y_ultima_desasignacion_sin_inventar_historial(): void
    {
        $reclamo = Reclamo::factory()->create();
        $admin = User::factory()->create(['rol' => 'admin']);
        $luis = User::factory()->create(['rol' => 'empleado']);
        $ana = User::factory()->create(['rol' => 'empleado']);
        Sanctum::actingAs($admin);
        $url = "/api/reclamos/{$reclamo->id}/asignacion";
        $detalle = "/api/admin/reclamos/{$reclamo->id}";
        $this->getJson($detalle)->assertJsonPath('data.ultima_desasignacion', null);
        $this->postJson($url, ['responsable_id' => $luis->id])->assertOk();
        $this->getJson($detalle)->assertJsonPath('data.asignado_por.id', $admin->id)
            ->assertJsonPath('data.ultima_desasignacion', null);
        $this->postJson($url, ['responsable_id' => $ana->id])->assertOk();
        $this->getJson($detalle)->assertJsonPath('data.responsable.id', $ana->id)
            ->assertJsonPath('data.ultima_desasignacion.responsable.id', $luis->id)
            ->assertJsonPath('data.ultima_desasignacion.autor.id', $admin->id);
        $this->postJson($url, ['responsable_id' => $ana->id])->assertOk();
        $this->getJson($detalle)->assertJsonPath('data.ultima_desasignacion.responsable.id', $luis->id);
        $this->deleteJson($url)->assertOk();
        $this->getJson($detalle)->assertJsonPath('data.responsable', null)
            ->assertJsonPath('data.ultima_desasignacion.responsable.id', $ana->id)
            ->assertJsonPath('data.ultima_desasignacion.autor.id', $admin->id);
        $this->assertDatabaseCount('historial_estados_reclamos', 0);
    }
}
