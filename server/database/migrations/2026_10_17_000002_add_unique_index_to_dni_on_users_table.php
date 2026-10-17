<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Impide dos cuentas con el mismo DNI. La columna sigue aceptando `null`
     * para las cuentas que no se crean desde el registro, como la del admin.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->unique('dni');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['dni']);
        });
    }
};
