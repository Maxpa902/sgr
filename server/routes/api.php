<?php

use App\Http\Controllers\ReclamoController;
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

    Route::middleware('rol:admin')->group(function (): void {
        Route::get('/usuarios', [UsuarioController::class, 'index'])->name('usuarios.index');
    });
});
