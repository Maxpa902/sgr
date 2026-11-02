<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reclamos', function (Blueprint $table) {
            $table->foreignId('responsable_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->foreignId('asignado_por_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->timestamp('asignado_en')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('reclamos', function (Blueprint $table) {
            $table->dropConstrainedForeignId('responsable_id');
            $table->dropConstrainedForeignId('asignado_por_id');
            $table->dropColumn('asignado_en');
        });
    }
};
