<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\Comentario;
use App\Models\Reclamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ComentarioControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_lista_los_comentarios_en_orden_con_autor_y_cuantos_le_quedan(): void
    {
        $ana = User::factory()->create(['rol' => 'ciudadano', 'nombre' => 'Ana', 'apellido' => 'Pérez']);
        $luis = User::factory()->create(['rol' => 'ciudadano', 'nombre' => 'Luis', 'apellido' => 'Gómez']);
        $reclamo = Reclamo::factory()->create();
        $segundo = $this->comentar($reclamo, $luis, 'Sigue igual', '2026-11-19 10:00:00');
        $primero = $this->comentar($reclamo, $ana, 'Pasa hace días', '2026-11-18 10:00:00', editadoEn: '2026-11-18 11:00:00');
        $this->comentar($reclamo, $ana, 'Ahora peor', '2026-11-20 10:00:00');
        $this->comentar(Reclamo::factory()->create(), $ana, 'De otro reclamo', '2026-11-20 10:00:00');
        Sanctum::actingAs($ana);

        $respuesta = $this->getJson("/api/reclamos/{$reclamo->id}/comentarios");

        $respuesta->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('meta.disponibles', 1)
            ->assertJsonPath('meta.motivo_bloqueo', null)
            ->assertJsonPath('meta.puede_modificar_propios', true);
        $respuesta->assertJsonPath('data.0.id', $primero->id)
            ->assertJsonPath('data.0.autor', 'Ana Pérez')
            ->assertJsonPath('data.0.es_mio', true)
            ->assertJsonPath('data.0.editado', true)
            ->assertJsonPath('data.0.creado_en', '2026-11-18T10:00:00+00:00');
        $respuesta->assertJsonPath('data.1.id', $segundo->id)
            ->assertJsonPath('data.1.autor', 'Luis Gómez')
            ->assertJsonPath('data.1.es_mio', false)
            ->assertJsonPath('data.1.editado', false);
    }

    public function test_el_listado_explica_por_que_no_puede_comentar_en_un_reclamo_finalizado(): void
    {
        $reclamo = Reclamo::factory()->enEstado('resuelto')->create();
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));

        $respuesta = $this->getJson("/api/reclamos/{$reclamo->id}/comentarios");

        $respuesta->assertOk()
            ->assertJsonPath('meta.motivo_bloqueo', 'El reclamo ya finalizó: los comentarios están cerrados.')
            ->assertJsonPath('meta.puede_modificar_propios', false);
    }

    public function test_con_tres_comentarios_no_puede_escribir_otro_pero_si_modificar_los_suyos(): void
    {
        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        $reclamo = Reclamo::factory()->create();
        Comentario::factory()->count(3)->for($reclamo)->for($vecino, 'usuario')->create();
        Sanctum::actingAs($vecino);

        $respuesta = $this->getJson("/api/reclamos/{$reclamo->id}/comentarios");

        $respuesta->assertOk()
            ->assertJsonPath('meta.disponibles', 0)
            ->assertJsonPath('meta.motivo_bloqueo', 'Ya tenés 3 comentarios en este reclamo. Borrá uno para escribir otro.')
            ->assertJsonPath('meta.puede_modificar_propios', true);
    }

    public function test_el_vecino_comenta_incluso_su_propio_reclamo_y_devuelve_201(): void
    {
        $creador = User::factory()->create(['rol' => 'ciudadano', 'nombre' => 'Ana', 'apellido' => 'Pérez']);
        $reclamo = Reclamo::factory()->for($creador, 'usuario')->create();
        Sanctum::actingAs($creador);

        $respuesta = $this->postJson("/api/reclamos/{$reclamo->id}/comentarios", ['contenido' => 'Ya pasaron tres días']);

        $respuesta->assertCreated()
            ->assertJsonPath('data.contenido', 'Ya pasaron tres días')
            ->assertJsonPath('data.autor', 'Ana Pérez')
            ->assertJsonPath('data.es_mio', true);
        $this->assertDatabaseHas('comentarios', [
            'reclamo_id' => $reclamo->id,
            'usuario_id' => $creador->id,
            'contenido' => 'Ya pasaron tres días',
        ]);
    }

    public function test_el_cuarto_comentario_del_mismo_usuario_devuelve_409(): void
    {
        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        $reclamo = Reclamo::factory()->create();
        Comentario::factory()->count(3)->for($reclamo)->for($vecino, 'usuario')->create();
        Sanctum::actingAs($vecino);

        $respuesta = $this->postJson("/api/reclamos/{$reclamo->id}/comentarios", ['contenido' => 'Uno más']);

        $respuesta->assertConflict()
            ->assertJsonPath('message', 'Ya tenés 3 comentarios en este reclamo. Borrá uno para escribir otro.');
        $this->assertDatabaseCount('comentarios', 3);
    }

    public function test_comentar_un_reclamo_finalizado_devuelve_409(): void
    {
        $reclamo = Reclamo::factory()->enEstado('rechazado')->create();
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));

        $respuesta = $this->postJson("/api/reclamos/{$reclamo->id}/comentarios", ['contenido' => 'Hola']);

        $respuesta->assertConflict()
            ->assertJsonPath('message', 'El reclamo ya finalizó: los comentarios están cerrados.');
        $this->assertDatabaseCount('comentarios', 0);
    }

    public function test_un_suspendido_no_puede_comentar_403(): void
    {
        $reclamo = Reclamo::factory()->create();
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano', 'suspendido_hasta' => now()->addDay()]));

        $respuesta = $this->postJson("/api/reclamos/{$reclamo->id}/comentarios", ['contenido' => 'Hola']);

        $respuesta->assertForbidden()
            ->assertJsonPath('message', 'Tu cuenta está suspendida y no puede comentar.');
        $this->assertDatabaseCount('comentarios', 0);
    }

    public function test_un_comentario_vacio_devuelve_422(): void
    {
        $reclamo = Reclamo::factory()->create();
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));

        $respuesta = $this->postJson("/api/reclamos/{$reclamo->id}/comentarios", ['contenido' => '   ']);

        $respuesta->assertUnprocessable()
            ->assertJsonValidationErrors(['contenido' => 'Escribí el comentario.']);
        $this->assertDatabaseCount('comentarios', 0);
    }

    public function test_el_admin_no_puede_comentar_403(): void
    {
        $reclamo = Reclamo::factory()->create();
        Sanctum::actingAs(User::factory()->create(['rol' => 'admin']));

        $respuesta = $this->postJson("/api/reclamos/{$reclamo->id}/comentarios", ['contenido' => 'Hola']);

        $respuesta->assertForbidden();
        $this->assertDatabaseCount('comentarios', 0);
    }

    public function test_editar_cambia_el_texto_y_lo_marca_como_editado(): void
    {
        $this->travelTo('2026-11-19 12:00:00');
        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        $comentario = $this->comentar(Reclamo::factory()->create(), $vecino, 'Con error de tipeo', '2026-11-19 10:00:00');
        Sanctum::actingAs($vecino);

        $respuesta = $this->patchJson("/api/comentarios/{$comentario->id}", ['contenido' => 'Sin error de tipeo']);

        $respuesta->assertOk()
            ->assertJsonPath('data.contenido', 'Sin error de tipeo')
            ->assertJsonPath('data.editado', true);
        $this->assertDatabaseHas('comentarios', [
            'id' => $comentario->id,
            'contenido' => 'Sin error de tipeo',
            'updated_at' => '2026-11-19 12:00:00',
        ]);
    }

    public function test_editar_un_comentario_ajeno_devuelve_403(): void
    {
        $comentario = Comentario::factory()->create(['contenido' => 'Original']);
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));

        $respuesta = $this->patchJson("/api/comentarios/{$comentario->id}", ['contenido' => 'Cambiado']);

        $respuesta->assertForbidden()
            ->assertJsonPath('message', 'Solo podés modificar tus propios comentarios.');
        $this->assertDatabaseHas('comentarios', ['id' => $comentario->id, 'contenido' => 'Original']);
    }

    public function test_editar_en_un_reclamo_finalizado_devuelve_409(): void
    {
        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        $reclamo = Reclamo::factory()->enEstado('resuelto')->create();
        $comentario = Comentario::factory()->for($reclamo)->for($vecino, 'usuario')->create(['contenido' => 'Original']);
        Sanctum::actingAs($vecino);

        $respuesta = $this->patchJson("/api/comentarios/{$comentario->id}", ['contenido' => 'Cambiado']);

        $respuesta->assertConflict();
        $this->assertDatabaseHas('comentarios', ['id' => $comentario->id, 'contenido' => 'Original']);
    }

    public function test_borrar_su_comentario_lo_elimina_y_devuelve_204(): void
    {
        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        $comentario = Comentario::factory()->for($vecino, 'usuario')->create();
        Sanctum::actingAs($vecino);

        $respuesta = $this->deleteJson("/api/comentarios/{$comentario->id}");

        $respuesta->assertNoContent();
        $this->assertModelMissing($comentario);
    }

    public function test_borrar_un_comentario_ajeno_devuelve_403(): void
    {
        $comentario = Comentario::factory()->create();
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));

        $respuesta = $this->deleteJson("/api/comentarios/{$comentario->id}");

        $respuesta->assertForbidden();
        $this->assertModelExists($comentario);
    }

    public function test_borrar_en_un_reclamo_finalizado_devuelve_409(): void
    {
        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        $reclamo = Reclamo::factory()->enEstado('rechazado')->create();
        $comentario = Comentario::factory()->for($reclamo)->for($vecino, 'usuario')->create();
        Sanctum::actingAs($vecino);

        $respuesta = $this->deleteJson("/api/comentarios/{$comentario->id}");

        $respuesta->assertConflict();
        $this->assertModelExists($comentario);
    }

    public function test_comentarios_de_un_reclamo_dado_de_baja_devuelve_404(): void
    {
        $reclamo = Reclamo::factory()->create();
        Comentario::factory()->for($reclamo)->create();
        $reclamo->delete();
        Sanctum::actingAs(User::factory()->create(['rol' => 'ciudadano']));

        $respuesta = $this->getJson("/api/reclamos/{$reclamo->id}/comentarios");

        $respuesta->assertNotFound();
    }

    /** Crea un comentario con fechas fijas; `editadoEn` simula una edición posterior. */
    private function comentar(
        Reclamo $reclamo,
        User $autor,
        string $contenido,
        string $creadoEn,
        ?string $editadoEn = null,
    ): Comentario {
        return Comentario::factory()->for($reclamo)->for($autor, 'usuario')->create([
            'contenido' => $contenido,
            'created_at' => $creadoEn,
            'updated_at' => $editadoEn ?? $creadoEn,
        ]);
    }
}
