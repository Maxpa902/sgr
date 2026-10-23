<?php

namespace App\Http\Controllers;

use App\Http\Resources\TipoReclamoResource;
use App\Models\TipoReclamo;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class TipoReclamoController extends Controller
{
    /**
     * Lista las categorías que se ofrecen para cargar reclamos nuevos.
     */
    public function index(): AnonymousResourceCollection
    {
        $tipos = TipoReclamo::where('activo', true)->orderBy('nombre')->get();

        return TipoReclamoResource::collection($tipos);
    }

    /** Lista todas las categorías para filtrar el directorio de reclamos admin. */
    public function adminIndex(): AnonymousResourceCollection
    {
        return TipoReclamoResource::collection(TipoReclamo::orderBy('nombre')->get());
    }
}
