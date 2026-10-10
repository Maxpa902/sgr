<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reclamos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('tipo_reclamo_id')->constrained('tipos_reclamo')->restrictOnDelete();
            $table->foreignId('estado_id')->constrained('estados_reclamo')->restrictOnDelete();
            $table->foreignId('empleado_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->foreignId('cuadrilla_id')->nullable()->constrained('cuadrillas')->restrictOnDelete();
            $table->string('titulo', 150);
            $table->text('descripcion');
            $table->string('foto', 255);
            $table->decimal('latitud', 10, 7);
            $table->decimal('longitud', 10, 7);
            $table->string('direccion', 255)->nullable();
            $table->softDeletes();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reclamos');
    }
};
