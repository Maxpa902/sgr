<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;

class ReclamoAdminDetalleResource extends ReclamoAdminResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $historial = $this->historialEstados;
        $cierre = in_array($this->estado->nombre, ['resuelto', 'rechazado'], true)
            ? $historial->last(fn ($evento) => $evento->estado_id === $this->estado_id)
            : null;
        $persona = fn ($usuario) => $usuario ? [
            'id' => $usuario->id,
            'nombre' => $usuario->nombre,
            'apellido' => $usuario->apellido,
        ] : null;

        return array_replace(parent::toArray($request), [
            'latitud' => (float) $this->latitud,
            'longitud' => (float) $this->longitud,
            'tipo' => [
                'id' => $this->tipoReclamo->id,
                'nombre' => $this->tipoReclamo->nombre,
                'icono' => $this->tipoReclamo->icono,
            ],
            'fotos' => $this->fotos->map(fn ($foto) => asset('storage/'.$foto->ruta))->values(),
            'responsable' => $this->responsable ? [
                'id' => $this->responsable->id,
                'nombre' => $this->responsable->nombre,
                'apellido' => $this->responsable->apellido,
            ] : null,
            'asignado_por_id' => $this->asignado_por_id,
            'asignado_por' => $persona($this->asignadoPor),
            'asignado_en' => $this->asignado_en?->toIso8601String(),
            'ultima_desasignacion' => $this->ultimoResponsable && $this->desasignado_en ? [
                'responsable' => $persona($this->ultimoResponsable),
                'autor' => $persona($this->desasignadoPor),
                'creado_en' => $this->desasignado_en->toIso8601String(),
            ] : null,
            'historial' => $historial->map(fn ($evento) => [
                'id' => $evento->id,
                'estado' => $evento->estado->nombre,
                'autor' => $persona($evento->usuario),
                'observacion' => $evento->observacion,
                'visibilidad' => $evento->visibilidad,
                'creado_en' => $evento->created_at->toIso8601String(),
            ])->values(),
            'cierre' => $cierre ? [
                'observacion' => $cierre->observacion,
                'creado_en' => $cierre->created_at->toIso8601String(),
                'autor' => $cierre->usuario ? [
                    'id' => $cierre->usuario->id,
                    'nombre' => $cierre->usuario->nombre,
                    'apellido' => $cierre->usuario->apellido,
                ] : null,
            ] : null,
        ]);
    }
}
