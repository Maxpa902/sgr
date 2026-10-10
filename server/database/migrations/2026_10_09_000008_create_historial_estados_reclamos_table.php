<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('historial_estados_reclamos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('reclamo_id')->constrained('reclamos')->restrictOnDelete();
            $table->foreignId('estado_id')->constrained('estados_reclamo')->restrictOnDelete();
            $table->foreignId('usuario_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->text('observacion')->nullable();
            $table->string('visibilidad', 20)->default('publica');
            $table->timestamp('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('historial_estados_reclamos');
    }
};
