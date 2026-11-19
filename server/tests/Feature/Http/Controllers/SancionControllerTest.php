<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\Reclamo;
use App\Models\Sancion;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SancionControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_ve_las_sanciones_del_vecino_activas_terminadas_y_revocadas(): void
    {
        $this->travelTo('2026-11-19 12:00:00');
        $admin = User::factory()->create(['rol' => 'admin']);
        $vecino = User::factory()->create(['rol' => 'ciudadano', 'suspendido_hasta' => '2026-12-18 12:00:00']);
        $terminada = $this->sancionar($vecino, ['created_at' => now()->subDays(40)]);
        $revocada = $this->sancionar($vecino, [
            'created_at' => now()->subDays(10),
            'revocada_en' => now()->subDays(2),
            'revocada_por_id' => $admin->id,
            'motivo_revocacion' => 'Se comprobó que el pozo existía',
        ]);
        $activa = $this->sancionar($vecino, ['created_at' => now()->subDay()]);
        $this->sancionar(User::factory()->create(['rol' => 'ciudadano']));
        Sanctum::actingAs($admin);

        $respuesta = $this->getJson("/api/admin/usuarios/{$vecino->id}/sanciones");

        $respuesta->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('usuario.suspendido_hasta', '2026-12-18T12:00:00+00:00');
        $respuesta->assertJsonPath('data.0.id', $activa->id)
            ->assertJsonPath('data.0.activa', true)
            ->assertJsonPath('data.0.reclamo.id', $activa->reclamo_id)
            ->assertJsonPath('data.0.termina_en', '2026-12-18T12:00:00+00:00');
        $respuesta->assertJsonPath('data.1.id', $revocada->id)
            ->assertJsonPath('data.1.activa', false)
            ->assertJsonPath('data.1.revocada_en', '2026-11-17T12:00:00+00:00')
            ->assertJsonPath('data.1.revocada_por.id', $admin->id)
            ->assertJsonPath('data.1.motivo_revocacion', 'Se comprobó que el pozo existía');
        $respuesta->assertJsonPath('data.2.id', $terminada->id)
            ->assertJsonPath('data.2.activa', false)
            ->assertJsonPath('data.2.termina_en', '2026-11-09T12:00:00+00:00')
            ->assertJsonPath('data.2.revocada_en', null);
    }

    public function test_revocar_guarda_quien_cuando_y_por_que_sin_borrar_la_sancion(): void
    {
        $this->travelTo('2026-11-19 12:00:00');
        $admin = User::factory()->create(['rol' => 'admin']);
        $sancion = $this->sancionar(User::factory()->create(['rol' => 'ciudadano']));
        Sanctum::actingAs($admin);

        $respuesta = $this->postJson("/api/admin/sanciones/{$sancion->id}/revocar", ['motivo' => 'El reclamo era real']);

        $respuesta->assertOk()
            ->assertJsonPath('data.id', $sancion->id)
            ->assertJsonPath('data.activa', false)
            ->assertJsonPath('data.revocada_en', '2026-11-19T12:00:00+00:00')
            ->assertJsonPath('data.revocada_por.id', $admin->id)
            ->assertJsonPath('data.motivo_revocacion', 'El reclamo era real');
        $this->assertModelExists($sancion);
        $this->assertDatabaseHas('sanciones', [
            'id' => $sancion->id,
            'revocada_en' => '2026-11-19 12:00:00',
            'revocada_por_id' => $admin->id,
            'motivo_revocacion' => 'El reclamo era real',
        ]);
    }

    public function test_revocar_sin_motivo_devuelve_422_y_la_sancion_sigue_activa(): void
    {
        $sancion = $this->sancionar(User::factory()->create(['rol' => 'ciudadano']));
        Sanctum::actingAs(User::factory()->create(['rol' => 'admin']));

        $respuesta = $this->postJson("/api/admin/sanciones/{$sancion->id}/revocar", ['motivo' => '   ']);

        $respuesta->assertUnprocessable()
            ->assertJsonValidationErrors(['motivo' => 'Escribí el motivo de la revocación.']);
        $this->assertDatabaseHas('sanciones', [
            'id' => $sancion->id,
            'revocada_en' => null,
            'revocada_por_id' => null,
            'motivo_revocacion' => null,
        ]);
    }

    public function test_revocar_una_sancion_ya_revocada_devuelve_409_y_conserva_la_primera_revocacion(): void
    {
        $primerAdmin = User::factory()->create(['rol' => 'admin']);
        $sancion = $this->sancionar(User::factory()->create(['rol' => 'ciudadano']), [
            'revocada_en' => now()->subDay(),
            'revocada_por_id' => $primerAdmin->id,
            'motivo_revocacion' => 'Primer motivo',
        ]);
        Sanctum::actingAs(User::factory()->create(['rol' => 'admin']));

        $respuesta = $this->postJson("/api/admin/sanciones/{$sancion->id}/revocar", ['motivo' => 'Otro motivo']);

        $respuesta->assertConflict()
            ->assertJsonPath('message', 'La sanción ya fue revocada.');
        $this->assertDatabaseHas('sanciones', [
            'id' => $sancion->id,
            'revocada_por_id' => $primerAdmin->id,
            'motivo_revocacion' => 'Primer motivo',
        ]);
    }

    public function test_revocar_la_unica_sancion_activa_levanta_la_suspension(): void
    {
        $this->travelTo('2026-11-19 12:00:00');
        $vecino = User::factory()->create(['rol' => 'ciudadano', 'suspendido_hasta' => '2026-12-18 12:00:00']);
        $sancion = $this->sancionar($vecino, ['created_at' => now()->subDay()]);
        Sanctum::actingAs(User::factory()->create(['rol' => 'admin']));

        $respuesta = $this->postJson("/api/admin/sanciones/{$sancion->id}/revocar", ['motivo' => 'Era real']);

        $respuesta->assertOk()
            ->assertJsonPath('usuario.suspendido_hasta', null);
        $this->assertDatabaseHas('users', ['id' => $vecino->id, 'suspendido_hasta' => null]);
    }

    public function test_revocar_con_otra_sancion_activa_deja_la_suspension_hasta_que_termine_esa(): void
    {
        $this->travelTo('2026-11-19 12:00:00');
        $vecino = User::factory()->create(['rol' => 'ciudadano', 'suspendido_hasta' => '2026-12-18 12:00:00']);
        $this->sancionar($vecino, ['created_at' => now()->subDays(9)]);
        $masReciente = $this->sancionar($vecino, ['created_at' => now()->subDay()]);
        Sanctum::actingAs(User::factory()->create(['rol' => 'admin']));

        $respuesta = $this->postJson("/api/admin/sanciones/{$masReciente->id}/revocar", ['motivo' => 'Era real']);

        $respuesta->assertOk()
            ->assertJsonPath('usuario.suspendido_hasta', '2026-12-10T12:00:00+00:00');
        $this->assertDatabaseHas('users', ['id' => $vecino->id, 'suspendido_hasta' => '2026-12-10 12:00:00']);
    }

    public function test_empleado_no_puede_ver_las_sanciones_de_un_vecino_403(): void
    {
        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        $this->sancionar($vecino);
        Sanctum::actingAs(User::factory()->create(['rol' => 'empleado']));

        $respuesta = $this->getJson("/api/admin/usuarios/{$vecino->id}/sanciones");

        $respuesta->assertForbidden();
    }

    public function test_empleado_no_puede_revocar_sanciones_403(): void
    {
        $sancion = $this->sancionar(User::factory()->create(['rol' => 'ciudadano']));
        Sanctum::actingAs(User::factory()->create(['rol' => 'empleado']));

        $respuesta = $this->postJson("/api/admin/sanciones/{$sancion->id}/revocar", ['motivo' => 'Era real']);

        $respuesta->assertForbidden();
        $this->assertDatabaseHas('sanciones', ['id' => $sancion->id, 'revocada_en' => null]);
    }

    /**
     * Crea una sanción del vecino sobre un reclamo suyo rechazado por falso.
     *
     * @param  array<string, mixed>  $atributos
     */
    private function sancionar(User $vecino, array $atributos = []): Sancion
    {
        $reclamo = Reclamo::factory()->enEstado('rechazado')->for($vecino, 'usuario')->create();

        return Sancion::forceCreate([
            'usuario_id' => $vecino->id,
            'reclamo_id' => $reclamo->id,
            ...$atributos,
        ]);
    }
}
