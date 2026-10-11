<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('fotos_reclamo', function (Blueprint $table) {
            $table->id();
            $table->foreignId('reclamo_id')->constrained('reclamos')->restrictOnDelete();
            $table->string('ruta', 255);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fotos_reclamo');
    }
};
