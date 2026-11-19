<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class HistorialPublicoControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_vecino_ve_los_cambios_en_orden_sin_autor_ni_observaciones_internas(): void
    {
        $empleado = User::factory()->create(['rol' => 'empleado']);
        $reclamo = Reclamo::factory()->enEstado('resuelto')->create();
        $this->registrarCambio($reclamo, 'resuelto', $empleado->id, '2026-11-21 11:00:00', 'Se reparó el cable', 'publica');
        $this->registrarCambio($reclamo, 'pendiente', $reclamo->usuario_id, '2026-11-18 09:00:00');
        $this->registrarCambio($reclamo, 'en_proceso', $empleado->id, '2026-11-19 10:00:00', 'Ir con escalera', 'interna');
        $otroReclamo = Reclamo::factory()->create();
        $this->registrarCambio($otroReclamo, 'pendiente', $otroReclamo->usuario_id, '2026-11-20 08:00:00');
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));

        $respuesta = $this->getJson("/api/reclamos/{$reclamo->id}/historial");

        $respuesta->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertExactJsonStructure(['data' => ['*' => ['id', 'estado', 'observacion', 'creado_en']]]);
        $respuesta->assertJsonPath('data.0.estado', 'pendiente')
            ->assertJsonPath('data.0.creado_en', '2026-11-18T09:00:00+00:00')
            ->assertJsonPath('data.1.estado', 'en_proceso')
            ->assertJsonPath('data.1.observacion', null)
            ->assertJsonPath('data.2.estado', 'resuelto')
            ->assertJsonPath('data.2.observacion', 'Se reparó el cable');
        $respuesta->assertDontSee('Ir con escalera');
    }

    public function test_historial_de_un_reclamo_dado_de_baja_devuelve_404(): void
    {
        $reclamo = Reclamo::factory()->create();
        $this->registrarCambio($reclamo, 'pendiente', $reclamo->usuario_id, '2026-11-18 09:00:00');
        $reclamo->delete();
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));

        $respuesta = $this->getJson("/api/reclamos/{$reclamo->id}/historial");

        $respuesta->assertNotFound();
    }

    public function test_historial_de_un_reclamo_privado_ajeno_devuelve_404(): void
    {
        $reclamo = Reclamo::factory()->privado()->create();
        $this->registrarCambio($reclamo, 'pendiente', $reclamo->usuario_id, '2026-11-18 09:00:00');
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));

        $respuesta = $this->getJson("/api/reclamos/{$reclamo->id}/historial");

        $respuesta->assertNotFound();
    }

    public function test_el_creador_ve_el_historial_de_su_reclamo_privado(): void
    {
        $creador = User::factory()->create(['rol' => 'ciudadano']);
        $reclamo = Reclamo::factory()->privado()->for($creador, 'usuario')->create();
        $this->registrarCambio($reclamo, 'pendiente', $creador->id, '2026-11-18 09:00:00');
        Sanctum::actingAs($creador);

        $respuesta = $this->getJson("/api/reclamos/{$reclamo->id}/historial");

        $respuesta->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.estado', 'pendiente');
    }

    /** Agrega una fila al historial del reclamo con la fecha indicada. */
    private function registrarCambio(
        Reclamo $reclamo,
        string $estado,
        ?int $autorId,
        string $fecha,
        ?string $observacion = null,
        string $visibilidad = 'publica',
    ): void {
        $reclamo->historialEstados()->create([
            'estado_id' => EstadoReclamo::firstOrCreate(['nombre' => $estado])->id,
            'usuario_id' => $autorId,
            'observacion' => $observacion,
            'visibilidad' => $visibilidad,
            'created_at' => $fecha,
        ]);
    }
}
