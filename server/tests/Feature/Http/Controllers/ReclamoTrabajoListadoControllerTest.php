<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\Reclamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReclamoTrabajoListadoControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_solo_personal_activo_puede_consultar_las_vistas(): void
    {
        $reclamo = Reclamo::factory()->create();
        $url = '/api/trabajo/reclamos?vista=disponibles';
        $this->getJson($url)->assertUnauthorized();
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));
        $this->getJson($url)->assertForbidden();
        $this->getJson("/api/trabajo/reclamos/{$reclamo->id}")->assertForbidden();
        Sanctum::actingAs(User::factory()->inactivo()->create(['rol' => 'empleado']));
        $this->getJson($url)->assertForbidden();
        Sanctum::actingAs(User::factory()->create(['rol' => 'empleado']));
        $this->getJson('/api/trabajo/reclamos?vista=otro')->assertUnprocessable();
        $this->getJson($url)->assertOk();
    }

    public function test_lista_solo_asignados_activos_o_pendientes_disponibles(): void
    {
        $empleado = User::factory()->create(['rol' => 'empleado']);
        $otro = User::factory()->create(['rol' => 'empleado']);
        $propio = Reclamo::factory()->create();
        $propio->forceFill(['responsable_id' => $empleado->id])->save();
        $enProceso = Reclamo::factory()->enEstado('en_proceso')->create();
        $enProceso->forceFill(['responsable_id' => $empleado->id])->save();
        $ajeno = Reclamo::factory()->create();
        $ajeno->forceFill(['responsable_id' => $otro->id])->save();
        $finalizado = Reclamo::factory()->enEstado('resuelto')->create();
        $finalizado->forceFill(['responsable_id' => $empleado->id])->save();
        $libre = Reclamo::factory()->privado()->create(['latitud' => -45.85, 'longitud' => -67.49]);
        $eliminado = Reclamo::factory()->create();
        $eliminado->delete();

        Sanctum::actingAs($empleado);
        $asignados = $this->getJson('/api/trabajo/reclamos?vista=asignados')->assertOk();
        $this->assertEqualsCanonicalizing([$propio->id, $enProceso->id], array_column($asignados->json('data'), 'id'));
        $disponibles = $this->getJson('/api/trabajo/reclamos?vista=disponibles')->assertOk();
        $this->assertSame([$libre->id], array_column($disponibles->json('data'), 'id'));
        $disponibles->assertJsonPath('data.0.latitud', -45.85)
            ->assertJsonPath('data.0.longitud', -67.49)
            ->assertJsonMissingPath('data.0.email_creador')
            ->assertJsonStructure(['data' => [['id', 'titulo', 'tipo', 'tipo_icono', 'estado', 'creado_en']]]);
    }

    public function test_la_paginacion_permite_recorrer_todos_los_disponibles(): void
    {
        Reclamo::factory()->count(35)->create();
        Sanctum::actingAs(User::factory()->create(['rol' => 'empleado']));
        $primera = $this->getJson('/api/trabajo/reclamos?vista=disponibles')->assertOk();
        $primera->assertJsonPath('meta.total', 35)->assertJsonCount(30, 'data');
        $cursor = $primera->json('meta.next_cursor');
        $this->assertNotNull($cursor);
        $segunda = $this->getJson('/api/trabajo/reclamos?vista=disponibles&cursor='.urlencode($cursor))->assertOk();
        $segunda->assertJsonCount(5, 'data')->assertJsonPath('meta.next_cursor', null);
        $ids = array_merge(array_column($primera->json('data'), 'id'), array_column($segunda->json('data'), 'id'));
        $this->assertCount(35, array_unique($ids));
    }

    public function test_detalle_de_personal_incluye_historial_interno(): void
    {
        $empleado = User::factory()->create(['rol' => 'empleado']);
        $reclamo = Reclamo::factory()->create();
        $reclamo->historialEstados()->create([
            'estado_id' => $reclamo->estado_id,
            'usuario_id' => $empleado->id,
            'observacion' => 'Nota de trabajo',
            'visibilidad' => 'interna',
            'created_at' => now(),
        ]);
        Sanctum::actingAs($empleado);
        $this->getJson("/api/trabajo/reclamos/{$reclamo->id}")
            ->assertOk()
            ->assertJsonPath('data.id', $reclamo->id)
            ->assertJsonPath('data.historial.0.observacion', 'Nota de trabajo')
            ->assertJsonPath('data.historial.0.visibilidad', 'interna');
    }
}
