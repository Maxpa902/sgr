<?php

use App\Http\Controllers\VotoController;
use App\Http\Controllers\ReclamoController;
use App\Http\Controllers\ReclamoAdminController;
use App\Http\Controllers\ReclamoTrabajoController;
use App\Http\Controllers\RegistroController;
use App\Http\Controllers\SesionController;
use App\Http\Controllers\TipoReclamoController;
use App\Http\Controllers\UsuarioActualController;
use App\Http\Controllers\UsuarioController;
use App\Http\Middleware\AsegurarCuentaActiva;
use Illuminate\Support\Facades\Route;

Route::get('/status', function () {
    return response()->json([
        'status' => 'ok',
        'message' => 'El servidor SGR está funcionando.',
    ]);
})->name('status');

Route::post('/registro', [RegistroController::class, 'store'])
    ->middleware('throttle:registro')
    ->name('registro.store');

Route::post('/login', [SesionController::class, 'store'])
    ->middleware('throttle:login')
    ->name('sesion.store');

Route::middleware(['auth:sanctum', AsegurarCuentaActiva::class])->group(function () {
    Route::post('/logout', [SesionController::class, 'destroy'])->name('sesion.destroy');
    Route::get('/usuario', [UsuarioActualController::class, 'show'])->name('usuario.show');
    Route::get('/tipos-reclamo', [TipoReclamoController::class, 'index'])->name('tipos-reclamo.index');
    Route::get('/reclamos', [ReclamoController::class, 'index'])->name('reclamos.index');
    
    Route::post('/reclamos', [ReclamoController::class, 'store'])->name('reclamos.store');

    Route::middleware('rol:admin,empleado')->group(function (): void {
        Route::get('/reclamos/{reclamo}/trabajo', [ReclamoTrabajoController::class, 'show'])->name('reclamos.trabajo');
        Route::post('/reclamos/{reclamo}/asignacion', [ReclamoTrabajoController::class, 'asignar'])->name('reclamos.asignar');
        Route::post('/reclamos/{reclamo}/comenzar', [ReclamoTrabajoController::class, 'comenzar'])->name('reclamos.comenzar');
    });
    
    Route::middleware('rol:admin')->group(function (): void {
        Route::delete('/reclamos/{reclamo}/asignacion', [ReclamoTrabajoController::class, 'desasignar'])->name('reclamos.desasignar');
        Route::post('/reclamos/{reclamo}/rechazar', [ReclamoTrabajoController::class, 'rechazar'])->name('reclamos.rechazar');
        Route::get('/usuarios', [UsuarioController::class, 'index'])->name('usuarios.index');
        Route::get('/admin/reclamos', [ReclamoAdminController::class, 'index'])->name('admin.reclamos.index');
        Route::get('/admin/reclamos/{reclamo}', [ReclamoAdminController::class, 'show'])->name('admin.reclamos.show');
        Route::get('/admin/tipos-reclamo', [TipoReclamoController::class, 'adminIndex'])->name('admin.tipos-reclamo.index');
    });
});
