<?php

use App\Http\Controllers\AdminUsuarioController;
use App\Http\Controllers\ComentarioController;
use App\Http\Controllers\HistorialPublicoController;
use App\Http\Controllers\ReclamoAdminController;
use App\Http\Controllers\ReclamoController;
use App\Http\Controllers\ReclamoTrabajoController;
use App\Http\Controllers\ReclamoTrabajoListadoController;
use App\Http\Controllers\RegistroController;
use App\Http\Controllers\SancionController;
use App\Http\Controllers\SesionController;
use App\Http\Controllers\TipoReclamoController;
use App\Http\Controllers\UsuarioActualController;
use App\Http\Controllers\UsuarioController;
use App\Http\Controllers\VotoController;
use App\Http\Controllers\AdminCuentaController;
use App\Http\Controllers\AdminTipoReclamoController;

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
    Route::match(['put', 'patch'], '/usuario', [UsuarioActualController::class, 'update'])->name('usuario.update');
    Route::get('/tipos-reclamo', [TipoReclamoController::class, 'index'])->name('tipos-reclamo.index');
    Route::get('/reclamos', [ReclamoController::class, 'index'])->name('reclamos.index');

    Route::post('/reclamos', [ReclamoController::class, 'store'])->name('reclamos.store');
    Route::match(['put', 'patch'], '/reclamos/{reclamo}', [ReclamoController::class, 'update'])->name('reclamos.update');
    Route::delete('/reclamos/{reclamo}', [ReclamoController::class, 'destroy'])->name('reclamos.destroy');
    Route::get('/reclamos/{reclamo}/votos', [VotoController::class, 'index'])->name('reclamos.votos.index');
    Route::post('/reclamos/{reclamo}/votar', [VotoController::class, 'store'])
        ->middleware('rol:ciudadano,empleado')->name('reclamos.votar');
    Route::get('/reclamos/{reclamo}/historial', [HistorialPublicoController::class, 'index'])->name('reclamos.historial.index');
    Route::get('/reclamos/{reclamo}/comentarios', [ComentarioController::class, 'index'])->name('reclamos.comentarios.index');
    Route::middleware('rol:ciudadano,empleado')->group(function (): void {
        Route::post('/reclamos/{reclamo}/comentarios', [ComentarioController::class, 'store'])->name('reclamos.comentarios.store');
        Route::patch('/comentarios/{comentario}', [ComentarioController::class, 'update'])->name('comentarios.update');
        Route::delete('/comentarios/{comentario}', [ComentarioController::class, 'destroy'])->name('comentarios.destroy');
    });

    Route::middleware('rol:admin,empleado')->group(function (): void {
        Route::get('/trabajo/reclamos', [ReclamoTrabajoListadoController::class, 'index'])->name('trabajo.reclamos.index');
        Route::get('/trabajo/reclamos/{reclamo}', [ReclamoTrabajoListadoController::class, 'show'])->name('trabajo.reclamos.show');
        Route::get('/reclamos/{reclamo}/trabajo', [ReclamoTrabajoController::class, 'show'])->name('reclamos.trabajo');
        Route::post('/reclamos/{reclamo}/asignacion', [ReclamoTrabajoController::class, 'asignar'])->name('reclamos.asignar');
        Route::post('/reclamos/{reclamo}/comenzar', [ReclamoTrabajoController::class, 'comenzar'])->name('reclamos.comenzar');
        Route::post('/reclamos/{reclamo}/finalizar', [ReclamoTrabajoController::class, 'finalizar'])->name('reclamos.finalizar');
        Route::post('/reclamos/{reclamo}/rechazar', [ReclamoTrabajoController::class, 'rechazar'])->name('reclamos.rechazar');
    });

    Route::middleware('rol:admin')->group(function (): void {
        Route::delete('/reclamos/{reclamo}/asignacion', [ReclamoTrabajoController::class, 'desasignar'])->name('reclamos.desasignar');
        Route::get('/usuarios', [UsuarioController::class, 'index'])->name('usuarios.index');
        Route::post('/usuarios', [UsuarioController::class, 'store'])->name('usuarios.store');
        Route::patch('/usuarios/{user}', [AdminCuentaController::class, 'actualizar'])->name('usuarios.actualizar');
        Route::post('/usuarios/{user}', [AdminCuentaController::class, 'actualizar'])->name('usuarios.actualizar.post');

        Route::get('/admin/reclamos', [ReclamoAdminController::class, 'index'])->name('admin.reclamos.index');
        Route::get('/admin/reclamos/{reclamo}', [ReclamoAdminController::class, 'show'])->name('admin.reclamos.show');

        Route::get('/admin/tipos-reclamo', [AdminTipoReclamoController::class, 'index'])->name('admin.tipos-reclamo.index');
        Route::post('/admin/tipos-reclamo', [AdminTipoReclamoController::class, 'store'])->name('admin.tipos-reclamo.store');
        Route::put('/admin/tipos-reclamo/{tipoReclamo}', [AdminTipoReclamoController::class, 'update'])->name('admin.tipos-reclamo.update');
        Route::post('/admin/tipos-reclamo/{tipoReclamo}/activo', [AdminTipoReclamoController::class, 'toggleActivo'])->name('admin.tipos-reclamo.activo');

        Route::get('/admin/usuarios-sancionados', [AdminUsuarioController::class, 'usuariosSancionados'])->name('admin.usuarios-sancionados.index');
        Route::get('/admin/usuarios/{usuario}/sanciones', [SancionController::class, 'index'])->name('admin.usuarios.sanciones.index');
        Route::post('/admin/sanciones/{sancion}/revocar', [SancionController::class, 'revocar'])->name('admin.sanciones.revocar');
    });
});
