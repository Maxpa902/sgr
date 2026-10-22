<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

Route::get('/', function () {
    return view('welcome');
});

// 1. RUTA GET: Muestra el formulario HTML en el navegador
Route::get('/probador-ia', function () {
    return '
    <div style="font-family: sans-serif; max-width: 500px; margin: 50px auto; padding: 25px; border: 1px solid #ccc; border-radius: 8px;">
        <h2 style="margin-top:0;">Probador de Moderación (Sightengine)</h2>
        <form action="/probador-ia" method="POST" enctype="multipart/form-data">
            ' . csrf_field() . '
            <p>Selecciona una imagen para analizar:</p>
            <input type="file" name="imagen" accept="image/*" required style="margin-bottom: 20px;"><br>
            <button type="submit" style="padding: 10px 20px; background: #28a745; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: bold;">
                Analizar Imagen
            </button>
        </form>
    </div>
    ';
});

// 2. RUTA POST: Recibe la imagen y consulta a Sightengine
Route::post('/probador-ia', function (Request $request) {
    $request->validate([
        'imagen' => ['required', 'image', 'max:5120'],
    ]);

    $file = $request->file('imagen');

    // Agregamos 'face-attributes' a los modelos a analizar
    $response = Http::attach(
        'media',
        file_get_contents($file->path()),
        $file->getClientOriginalName()
    )->post('https://api.sightengine.com/1.0/check.json', [
        'models'     => 'nudity-2.0,gore,face-attributes',
        'api_user'   => config('services.sightengine.user'),
        'api_secret' => config('services.sightengine.secret'),
    ]);

    if (!$response->successful()) {
        return response()->json([
            'status' => 'Error al conectar con Sightengine',
            'response' => $response->json()
        ], 500);
    }

    $result = $response->json();
    $nudity = $result['nudity'] ?? [];
    $classes = $nudity['suggestive_classes'] ?? [];
    $faces   = $result['faces'] ?? [];

    // Detección de personas / rostros
    $cantidadRostros = count($faces);

    // Métrica de desnudez y gore
    $rawNudity      = $nudity['raw'] ?? 0;
    $erotica        = $nudity['erotica'] ?? 0;
    $sexualActivity = $nudity['sexual_activity'] ?? 0;
    $goreProb       = $result['gore']['prob'] ?? 0;

    $suggestive    = $nudity['suggestive'] ?? 0;
    $bikini        = $classes['bikini'] ?? 0;
    $maleChest     = $classes['male_chest'] ?? 0;
    $lingerie      = $classes['lingerie'] ?? 0;
    $maleUnderwear = $classes['male_underwear'] ?? 0;
    $cleavage      = $classes['cleavage'] ?? 0;

    $umbralRopa = 0.20;
    $umbralExplicito = 0.50;

    $motivo = null;

    // Regla de descarte por presencia de personas
    if ($cantidadRostros > 0) {
        $motivo = "Se detectó la presencia de personas/rostros ({$cantidadRostros} detectado/s). Los reclamos solo deben mostrar el daño público.";
    } elseif ($rawNudity > $umbralExplicito || $erotica > $umbralExplicito || $sexualActivity > $umbralExplicito) {
        $motivo = 'Contenido explícito o erótico detectado.';
    } elseif ($goreProb > $umbralExplicito) {
        $motivo = 'Contenido violento o gore detectado.';
    } elseif ($bikini > $umbralRopa || $maleChest > $umbralRopa || $lingerie > $umbralRopa || $maleUnderwear > $umbralRopa) {
        $motivo = 'Persona con torso descubierto, ropa interior o traje de baño detectado.';
    } elseif ($suggestive > 0.40) {
        $motivo = 'Imagen con contenido sugestivo no apto para reclamos urbanos.';
    }

    $bloqueada = !is_null($motivo);

    return response()->json([
        'resultado' => $bloqueada ? 'RECHAZADA ❌' : 'APROBADA ✅',
        'motivo_bloqueo' => $motivo ?? 'La imagen es válida para un reporte municipal.',
        'metricas_analizadas' => [
            'personas_rostros_detectados' => $cantidadRostros,
            'desnudez_raw'   => round($rawNudity * 100, 2) . '%',
            'gore_sangre'    => round($goreProb * 100, 2) . '%',
            'torso_al_aire'  => round($maleChest * 100, 2) . '%',
            'bikini_malla'   => round($bikini * 100, 2) . '%',
            'sugestivo'      => round($suggestive * 100, 2) . '%',
        ],
    ]);
});