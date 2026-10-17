<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reclamos', function (Blueprint $table) {
            $table->string('titulo', 150)->nullable()->change();
        });
    }

    /**
     * Vuelve a exigir el título. Los reclamos sin título reciben el nombre de su categoría,
     * que es lo mismo que la app muestra mientras el título está vacío.
     */
    public function down(): void
    {
        DB::table('reclamos')->whereNull('titulo')->update([
            'titulo' => DB::raw('(select nombre from tipos_reclamo where tipos_reclamo.id = reclamos.tipo_reclamo_id)'),
        ]);

        Schema::table('reclamos', function (Blueprint $table) {
            $table->string('titulo', 150)->nullable(false)->change();
        });
    }
};
