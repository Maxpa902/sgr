<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\Reclamo;
use App\Models\EstadoReclamo;
use App\Models\TipoReclamo;
use App\Models\User;
use App\Models\Voto;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReclamoControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_detail_requires_authentication_and_respects_visibility_and_deletion(): void
    {
        $autor = User::factory()->create();
        $privado = Reclamo::factory()->privado()->create(['usuario_id' => $autor->id]);
        $publico = Reclamo::factory()->create();
        $borrado = Reclamo::factory()->create();
        $borrado->delete();

        $this->getJson("/api/reclamos/{$publico->id}")->assertUnauthorized();
        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/reclamos/{$privado->id}")->assertNotFound();
        $this->getJson("/api/reclamos/{$borrado->id}")->assertNotFound();
        $this->getJson("/api/reclamos/{$publico->id}")->assertOk()->assertJsonPath('data.id', $publico->id);
        Sanctum::actingAs($autor);
        $this->getJson("/api/reclamos/{$privado->id}")->assertOk()->assertJsonPath('data.id', $privado->id);
    }

    public function test_detail_permissions_reflect_author_state_and_suspension(): void
    {
        $autor = User::factory()->create(['rol' => 'ciudadano']);
        $reclamo = Reclamo::factory()->create(['usuario_id' => $autor->id]);
        Sanctum::actingAs($autor);
        $this->getJson("/api/reclamos/{$reclamo->id}")->assertOk()
            ->assertJsonPath('data.puede_editar', true)
            ->assertJsonPath('data.puede_eliminar', true)
            ->assertJsonPath('data.puede_votar', false);

        $autor->forceFill(['suspendido_hasta' => now()->addDay()])->save();
        $this->getJson("/api/reclamos/{$reclamo->id}")->assertOk()
            ->assertJsonPath('data.puede_editar', false)
            ->assertJsonPath('data.puede_eliminar', true);

        $otroEstado = EstadoReclamo::firstOrCreate(['nombre' => 'en_proceso']);
        $reclamo->historialEstados()->create([
            'estado_id' => $otroEstado->id,
            'usuario_id' => $autor->id,
            'visibilidad' => 'publica',
            'created_at' => now(),
        ]);
        $this->getJson("/api/reclamos/{$reclamo->id}")->assertOk()
            ->assertJsonPath('data.puede_eliminar', false);

        $vecino = User::factory()->create(['rol' => 'ciudadano']);
        Sanctum::actingAs($vecino);
        $this->getJson("/api/reclamos/{$reclamo->id}")->assertOk()
            ->assertJsonPath('data.puede_votar', true)
            ->assertJsonPath('data.puede_editar', false);
        $vecino->forceFill(['suspendido_hasta' => now()->addDay()])->save();
        $this->getJson("/api/reclamos/{$reclamo->id}")->assertOk()->assertJsonPath('data.puede_votar', false);

        $finalizado = Reclamo::factory()->enEstado('resuelto')->create(['usuario_id' => $autor->id]);
        Sanctum::actingAs($autor);
        $this->getJson("/api/reclamos/{$finalizado->id}")->assertOk()
            ->assertJsonPath('data.puede_editar', false)
            ->assertJsonPath('data.puede_eliminar', false)
            ->assertJsonPath('data.puede_votar', false);
    }

    public function test_returns_401_when_no_token_is_provided(): void
    {
        $this->getJson('/api/reclamos')->assertUnauthorized();
    }

    public function test_returns_pin_data_with_confirmation_and_denial_counts(): void
    {
        $reclamo = Reclamo::factory()->create([
            'titulo' => 'Poste de luz caído',
            'latitud' => -45.8641234,
            'longitud' => -67.4965432,
        ]);
        Voto::factory()->count(2)->for($reclamo)->create();
        Voto::factory()->desmiente()->for($reclamo)->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/reclamos')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $reclamo->id)
            ->assertJsonPath('data.0.titulo', 'Poste de luz caído')
            ->assertJsonPath('data.0.latitud', -45.8641234)
            ->assertJsonPath('data.0.longitud', -67.4965432)
            ->assertJsonPath('data.0.estado', 'pendiente')
            ->assertJsonPath('data.0.tipo.id', $reclamo->tipo_reclamo_id)
            ->assertJsonPath('data.0.confirmaciones', 2)
            ->assertJsonPath('data.0.desmentidas', 1);
    }

    public function test_uses_the_category_name_as_title_when_the_claim_has_none(): void
    {
        $agua = TipoReclamo::factory()->create(['nombre' => 'Agua potable']);
        Reclamo::factory()->sinTitulo()->for($agua, 'tipoReclamo')->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/reclamos')
            ->assertOk()
            ->assertJsonPath('data.0.titulo', 'Agua potable');
    }

    public function test_lists_only_public_active_claims_by_default(): void
    {
        $pendiente = Reclamo::factory()->create();
        $enProceso = Reclamo::factory()->enEstado('en_proceso')->create();
        Reclamo::factory()->privado()->create();
        Reclamo::factory()->create()->delete();
        Reclamo::factory()->enEstado('resuelto')->create();
        Reclamo::factory()->enEstado('rechazado')->create();
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/reclamos');

        $response->assertOk();
        $this->assertEqualsCanonicalizing([$pendiente->id, $enProceso->id], $response->json('data.*.id'));
    }

    public function test_estados_filter_returns_claims_in_any_of_the_given_states(): void
    {
        $pendiente = Reclamo::factory()->create();
        Reclamo::factory()->enEstado('en_proceso')->create();
        $resuelto = Reclamo::factory()->enEstado('resuelto')->create();
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/reclamos?estados[]=pendiente&estados[]=resuelto');

        $response->assertOk();
        $this->assertEqualsCanonicalizing([$pendiente->id, $resuelto->id], $response->json('data.*.id'));
    }

    public function test_tipos_filter_returns_only_claims_of_the_given_categories(): void
    {
        $agua = TipoReclamo::factory()->create();
        $luz = TipoReclamo::factory()->create();
        $reclamoDeAgua = Reclamo::factory()->for($agua, 'tipoReclamo')->create();
        $reclamoDeLuz = Reclamo::factory()->for($luz, 'tipoReclamo')->create();
        Reclamo::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson("/api/reclamos?tipos[]={$agua->id}&tipos[]={$luz->id}");

        $response->assertOk();
        $this->assertEqualsCanonicalizing([$reclamoDeAgua->id, $reclamoDeLuz->id], $response->json('data.*.id'));
    }

    public function test_includes_the_category_icon_for_the_pin(): void
    {
        $agua = TipoReclamo::factory()->create(['icono' => 'agua']);
        Reclamo::factory()->for($agua, 'tipoReclamo')->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/reclamos')
            ->assertOk()
            ->assertJsonPath('data.0.tipo.icono', 'agua');
    }

    public function test_rejects_unknown_estado_with_422(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/reclamos?estados[]=archivado')
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['estados.0' => 'El estado seleccionado no existe.']);
    }
}
