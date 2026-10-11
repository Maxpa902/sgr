<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sanciones', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('reclamo_id')->unique()->constrained('reclamos')->restrictOnDelete();
            $table->timestamp('revocada_en')->nullable();
            $table->foreignId('revocada_por_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->text('motivo_revocacion')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sanciones');
    }
};
