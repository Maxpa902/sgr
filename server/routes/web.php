<?php

use Illuminate\Support\Facades\Route;

Route::get('/api/status', function () {
    return response()->json([
        'status' => 'ok',
        'message' => 'El servidor SGR está funcionando.',
    ]);
});

Route::get('/', function () {
    return view('welcome');
});
