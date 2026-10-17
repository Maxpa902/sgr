<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Quita las cuadrillas y la asignación de reclamos: cualquier operario puede tomar
     * cualquier reclamo y el historial registra quién hizo cada cambio.
     */
    public function up(): void
    {
        Schema::table('reclamos', function (Blueprint $table) {
            $table->dropConstrainedForeignId('empleado_id');
            $table->dropConstrainedForeignId('cuadrilla_id');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropConstrainedForeignId('cuadrilla_id');
        });

        Schema::dropIfExists('cuadrillas');
    }

    /**
     * Restaura la estructura, pero no las cuadrillas ni las asignaciones que existían.
     */
    public function down(): void
    {
        Schema::create('cuadrillas', function (Blueprint $table) {
            $table->id();
            $table->string('nombre', 100)->unique();
            $table->boolean('activo')->default(true);
            $table->timestamps();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('cuadrilla_id')->nullable()->constrained('cuadrillas')->restrictOnDelete();
        });

        Schema::table('reclamos', function (Blueprint $table) {
            $table->foreignId('empleado_id')->nullable()->after('estado_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('cuadrilla_id')->nullable()->after('empleado_id')->constrained('cuadrillas')->restrictOnDelete();
        });
    }
};
