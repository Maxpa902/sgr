<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\Reclamo;
use App\Models\TipoReclamo;
use App\Models\User;
use App\Models\Voto;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReclamoControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_returns_401_when_no_token_is_provided(): void
    {
        $this->getJson('/api/reclamos')->assertUnauthorized();
    }

    public function test_returns_pin_data_with_confirmation_and_denial_counts(): void
    {
        $reclamo = Reclamo::factory()->create(['latitud' => -45.8641234, 'longitud' => -67.4965432]);
        Voto::factory()->count(2)->for($reclamo)->create();
        Voto::factory()->desmiente()->for($reclamo)->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/reclamos')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $reclamo->id)
            ->assertJsonPath('data.0.latitud', -45.8641234)
            ->assertJsonPath('data.0.longitud', -67.4965432)
            ->assertJsonPath('data.0.estado', 'pendiente')
            ->assertJsonPath('data.0.tipo.id', $reclamo->tipo_reclamo_id)
            ->assertJsonPath('data.0.confirmaciones', 2)
            ->assertJsonPath('data.0.desmentidas', 1);
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

    public function test_estado_filter_returns_only_claims_in_that_state(): void
    {
        Reclamo::factory()->create();
        $resuelto = Reclamo::factory()->enEstado('resuelto')->create();
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/reclamos?estado=resuelto');

        $response->assertOk();
        $this->assertSame([$resuelto->id], $response->json('data.*.id'));
    }

    public function test_tipo_filter_returns_only_claims_of_that_category(): void
    {
        $agua = TipoReclamo::factory()->create();
        $reclamoDeAgua = Reclamo::factory()->for($agua, 'tipoReclamo')->create();
        Reclamo::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson("/api/reclamos?tipo_reclamo_id={$agua->id}");

        $response->assertOk();
        $this->assertSame([$reclamoDeAgua->id], $response->json('data.*.id'));
    }

    public function test_rejects_unknown_estado_with_422(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/reclamos?estado=archivado')
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['estado']);
    }
}
