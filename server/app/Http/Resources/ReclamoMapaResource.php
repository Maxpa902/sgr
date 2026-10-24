<?php

namespace App\Http\Resources;

use App\Models\Reclamo;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Datos mínimos de un reclamo para dibujar su pin en el mapa.
 *
 * @mixin Reclamo
 */
class ReclamoMapaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $usuario = $request->user();
        
        // Obtener el voto realizado por el usuario autenticado (si existe)
        $miVoto = $usuario 
            ? $this->votos()->where('usuario_id', $usuario->id)->value('valor') 
            : null;

        return [
            'id' => $this->id,
            'usuario_id' => $this->usuario_id,
            'titulo' => $this->titulo_visible,
            'descripcion' => $this->descripcion,
            'latitud' => (float) $this->latitud,
            'longitud' => (float) $this->longitud,
            'direccion' => $this->direccion,
            'tipo' => new TipoReclamoResource($this->whenLoaded('tipoReclamo')),
            'estado' => $this->estado ? $this->estado->nombre : 'pendiente',
            'confirmaciones' => $this->confirmaciones_count ?? 0,
            'desmentidas' => $this->desmentidas_count ?? 0,
            'mi_voto' => $miVoto, // 👈 'confirma', 'desmiente' o null
            'fotos' => $this->whenLoaded('fotos', function () {
                return $this->fotos->map(fn ($foto) => asset('storage/' . $foto->ruta));
            }, []),
            'creado_en' => $this->created_at->toIso8601String(),
        ];
    }
}