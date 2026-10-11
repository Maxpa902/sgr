<?php

namespace App\Http\Controllers;

use App\Http\Resources\UsuarioResource;
use Illuminate\Http\Request;

class UsuarioActualController extends Controller
{
    public function show(Request $request): UsuarioResource
    {
        return new UsuarioResource($request->user());
    }
}
