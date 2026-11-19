<?php

namespace App\Http\Controllers;

use App\Http\Resources\TipoReclamoResource;
use App\Models\TipoReclamo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class AdminTipoReclamoController extends Controller
{
    /**
     * Lista todas las categorías para la gestión administrativa.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $tipos = TipoReclamo::withCount('reclamos')
            ->orderBy('nombre')
            ->get();

        return TipoReclamoResource::collection($tipos);
    }

    /**
     * Da de alta una nueva categoría de reclamo.
     */
    public function store(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'nombre' => ['required', 'string', 'max:255', 'unique:tipos_reclamo,nombre'],
            'descripcion' => ['nullable', 'string', 'max:1000'],
            'icono' => ['nullable', 'string', 'max:100'],
            'activo' => ['sometimes', 'boolean'],
        ]);

        $tipo = TipoReclamo::create([
            'nombre' => $datos['nombre'],
            'descripcion' => $datos['descripcion'] ?? null,
            'icono' => $datos['icono'] ?? null,
            'activo' => $datos['activo'] ?? true,
        ]);

        return (new TipoReclamoResource($tipo))
            ->additional(['message' => 'Categoría creada correctamente.'])
            ->response()
            ->setStatusCode(201);
    }

    /**
     * Edita una categoría existente.
     */
    public function update(Request $request, TipoReclamo $tipoReclamo): TipoReclamoResource
    {
        $datos = $request->validate([
            'nombre' => ['required', 'string', 'max:255', Rule::unique('tipos_reclamo', 'nombre')->ignore($tipoReclamo->id)],
            'descripcion' => ['nullable', 'string', 'max:1000'],
            'icono' => ['nullable', 'string', 'max:100'],
            'activo' => ['sometimes', 'boolean'],
        ]);

        $tipoReclamo->update($datos);

        return (new TipoReclamoResource($tipoReclamo->fresh()))
            ->additional(['message' => 'Categoría actualizada correctamente.']);
    }

    /**
     * Desactiva (o activa) una categoría de reclamo.
     */
    public function toggleActivo(Request $request, TipoReclamo $tipoReclamo): TipoReclamoResource
    {
        $activo = $request->validate([
            'activo' => ['required', 'boolean'],
        ])['activo'];

        $tipoReclamo->update(['activo' => $activo]);
        $estadoTexto = $activo ? 'activada' : 'desactivada';

        return (new TipoReclamoResource($tipoReclamo->fresh()))
            ->additional(['message' => "Categoría {$estadoTexto} correctamente."]);
    }
}
