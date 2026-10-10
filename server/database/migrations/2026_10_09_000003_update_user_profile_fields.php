<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->renameColumn('name', 'nombre');
            $table->string('apellido', 100);
            $table->string('telefono', 30)->nullable();
            $table->string('dni', 20)->nullable();
            $table->string('estado_verificacion', 20)->default('no_solicitada');
            $table->string('metodo_verificacion', 30)->nullable();
            $table->string('referencia_verificacion', 255)->nullable();
            $table->timestamp('identidad_verificada_en')->nullable();
            $table->enum('rol', ['ciudadano', 'empleado', 'admin'])->default('ciudadano');
            $table->boolean('activo')->default(true);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'apellido',
                'telefono',
                'dni',
                'estado_verificacion',
                'metodo_verificacion',
                'referencia_verificacion',
                'identidad_verificada_en',
                'rol',
                'activo',
            ]);
            $table->renameColumn('nombre', 'name');
        });
    }
};
