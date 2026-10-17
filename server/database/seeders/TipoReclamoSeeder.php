<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class TipoReclamoSeeder extends Seeder
{
    public function run(): void
    {
        $ahora = now();

        DB::table('tipos_reclamo')
            ->whereIn('nombre', ['Baches y calzada', 'Residuos y limpieza', 'Veredas y accesibilidad', 'Señalización'])
            ->update(['activo' => false, 'updated_at' => $ahora]);

        DB::table('tipos_reclamo')->upsert([
            [
                'nombre' => 'Energía eléctrica',
                'descripcion' => 'Cortes, fallas u otros problemas del servicio eléctrico.',
                'icono' => 'electricidad',
                'activo' => true,
                'created_at' => $ahora,
                'updated_at' => $ahora,
            ],
            [
                'nombre' => 'Alumbrado público',
                'descripcion' => 'Luminarias apagadas, dañadas o con funcionamiento irregular en la vía pública.',
                'icono' => 'alumbrado',
                'activo' => true,
                'created_at' => $ahora,
                'updated_at' => $ahora,
            ],
            [
                'nombre' => 'Agua potable',
                'descripcion' => 'Cortes, pérdidas u otros problemas del servicio de agua potable.',
                'icono' => 'agua',
                'activo' => true,
                'created_at' => $ahora,
                'updated_at' => $ahora,
            ],
            [
                'nombre' => 'Cloacas y saneamiento',
                'descripcion' => 'Obstrucciones, pérdidas u otros problemas de la red cloacal.',
                'icono' => 'cloacas',
                'activo' => true,
                'created_at' => $ahora,
                'updated_at' => $ahora,
            ],
            [
                'nombre' => 'Telefonía e internet',
                'descripcion' => 'Interrupciones u otros problemas del servicio de telefonía o internet.',
                'icono' => 'telefonia',
                'activo' => true,
                'created_at' => $ahora,
                'updated_at' => $ahora,
            ],
        ], ['nombre'], ['descripcion', 'icono', 'activo', 'updated_at']);
    }
}
