<?php

namespace Tests\Feature\Database\Seeders;

use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\DemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class DatabaseSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_creates_one_demo_account_per_role_with_the_documented_password(): void
    {
        $this->seed(DatabaseSeeder::class);

        foreach (['vecino@sgr.test' => 'ciudadano', 'operario@sgr.test' => 'empleado', 'admin@sgr.test' => 'admin'] as $email => $rol) {
            $usuario = User::where('email', $email)->sole();
            $this->assertSame($rol, $usuario->rol);
            $this->assertTrue(Hash::check(DemoSeeder::PASSWORD, $usuario->password));
        }
    }

    public function test_places_claims_in_comodoro_rada_tilly_and_caleta_cordova(): void
    {
        $this->seed(DatabaseSeeder::class);

        $this->assertGreaterThanOrEqual(20, Reclamo::count());
        $this->assertTrue(Reclamo::where('direccion', 'Rada Tilly')->exists());
        $this->assertTrue(Reclamo::where('direccion', 'Caleta Córdova')->exists());
    }

    public function test_respects_the_claim_rules(): void
    {
        $this->seed(DatabaseSeeder::class);

        $activosPorUsuario = Reclamo::whereHas('estado', fn ($query) => $query->whereIn('nombre', EstadoReclamo::ACTIVOS))
            ->selectRaw('usuario_id, count(*) as total')
            ->groupBy('usuario_id')
            ->pluck('total');
        $this->assertLessThanOrEqual(3, $activosPorUsuario->max());

        foreach (Reclamo::with(['votos', 'historialEstados.estado'])->get() as $reclamo) {
            $this->assertNotContains($reclamo->usuario_id, $reclamo->votos->pluck('usuario_id'), "El creador votó el reclamo {$reclamo->id}.");
            $this->assertSame('pendiente', $reclamo->historialEstados->sortBy('id')->first()->estado->nombre);
        }
    }

    public function test_does_not_duplicate_data_when_run_twice(): void
    {
        $this->seed(DatabaseSeeder::class);
        $reclamos = Reclamo::count();

        $this->seed(DatabaseSeeder::class);

        $this->assertSame($reclamos, Reclamo::count());
    }
}
