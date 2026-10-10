<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class EstadoReclamoSeeder extends Seeder
{
    public function run(): void
    {
        $ahora = now();

        DB::table('estados_reclamo')->insertOrIgnore([
            ['nombre' => 'pendiente', 'created_at' => $ahora, 'updated_at' => $ahora],
            ['nombre' => 'en_proceso', 'created_at' => $ahora, 'updated_at' => $ahora],
            ['nombre' => 'resuelto', 'created_at' => $ahora, 'updated_at' => $ahora],
            ['nombre' => 'rechazado', 'created_at' => $ahora, 'updated_at' => $ahora],
        ]);
    }
}
