<?php

namespace App\Http\Controllers;

use App\Http\Resources\UsuarioAdminResource;
use App\Models\User;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class UsuarioController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        $usuarios = User::query()
            ->select(['id', 'nombre', 'apellido', 'email', 'rol', 'activo'])
            ->orderBy('apellido')
            ->orderBy('nombre')
            ->get();

        return UsuarioAdminResource::collection($usuarios);
    }
}
