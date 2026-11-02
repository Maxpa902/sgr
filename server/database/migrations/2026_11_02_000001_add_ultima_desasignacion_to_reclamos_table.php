<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reclamos', function (Blueprint $table) {
            $table->foreignId('ultimo_responsable_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->foreignId('desasignado_por_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->timestamp('desasignado_en')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('reclamos', function (Blueprint $table) {
            $table->dropConstrainedForeignId('ultimo_responsable_id');
            $table->dropConstrainedForeignId('desasignado_por_id');
            $table->dropColumn('desasignado_en');
        });
    }
};
