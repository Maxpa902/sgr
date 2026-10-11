<?php

namespace Tests\Feature\Http\Controllers;

use App\Models\TipoReclamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TipoReclamoControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_returns_401_when_no_token_is_provided(): void
    {
        $this->getJson('/api/tipos-reclamo')->assertUnauthorized();
    }

    public function test_lists_only_active_categories_sorted_by_name(): void
    {
        TipoReclamo::factory()->create(['nombre' => 'Cloacas']);
        TipoReclamo::factory()->create(['nombre' => 'Agua potable']);
        TipoReclamo::factory()->inactivo()->create(['nombre' => 'Baches']);
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/tipos-reclamo');

        $response->assertOk();
        $this->assertSame(['Agua potable', 'Cloacas'], $response->json('data.*.nombre'));
    }
}
