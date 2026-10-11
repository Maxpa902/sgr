<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('fotos_reclamo')->insertUsing(
            ['reclamo_id', 'ruta', 'created_at', 'updated_at'],
            DB::table('reclamos')->select('id', 'foto', 'created_at', 'updated_at'),
        );

        Schema::table('reclamos', function (Blueprint $table) {
            $table->dropColumn('foto');
        });
    }

    /**
     * Restaura la primera foto de cada reclamo. La columna vuelve como `nullable`
     * porque la tabla puede tener reclamos sin fotos.
     */
    public function down(): void
    {
        Schema::table('reclamos', function (Blueprint $table) {
            $table->string('foto', 255)->nullable()->after('descripcion');
        });

        DB::table('fotos_reclamo')->orderByDesc('id')->each(function (object $foto): void {
            DB::table('reclamos')->where('id', $foto->reclamo_id)->update(['foto' => $foto->ruta]);
        });

        DB::table('fotos_reclamo')->delete();
    }
};
