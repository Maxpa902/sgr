<?php

namespace App\Http\Controllers;

use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use App\Models\Sancion;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ReclamoTrabajoController extends Controller
{
    public function show(Reclamo $reclamo): JsonResponse
    {
        return $this->respuesta($reclamo->load(['estado', 'responsable']));
    }

    public function asignar(Request $request, Reclamo $reclamo): JsonResponse
    {
        $datos = $request->validate(['responsable_id' => ['required', 'integer', Rule::exists('users', 'id')]]);
        $actor = $request->user();
        $responsable = User::findOrFail($datos['responsable_id']);

        abort_unless($responsable->activo && ($responsable->rol === 'empleado' || ($responsable->rol === 'admin' && $responsable->id === $actor->id)), 422, 'El responsable debe ser un empleado activo o el administrador actual.');
        abort_if($actor->rol === 'empleado' && $actor->id !== $responsable->id, 403, 'Solo podés tomar un reclamo para vos.');

        $pendiente = EstadoReclamo::where('nombre', 'pendiente')->firstOrFail();
        $actualizado = DB::transaction(function () use ($reclamo, $actor, $responsable, $pendiente) {
            $query = Reclamo::whereKey($reclamo->id)->where('estado_id', $pendiente->id);
            if ($actor->rol === 'empleado') {
                $query->whereNull('responsable_id');
            }

            // Un único UPDATE captura al responsable anterior de forma atómica.
            // responsable_id se actualiza al final para conservar el valor previo
            // también en motores que evalúan SET de izquierda a derecha.
            $responsableId = (int) $responsable->id;
            $actorId = (int) $actor->id;
            $fecha = now();
            $fechaSql = DB::connection()->getPdo()->quote($fecha->format('Y-m-d H:i:s'));
            $reemplazado = "responsable_id IS NOT NULL AND responsable_id <> {$responsableId}";
            $mismoResponsable = "responsable_id = {$responsableId}";

            return $query->update([
                'ultimo_responsable_id' => DB::raw("CASE WHEN {$reemplazado} THEN responsable_id ELSE ultimo_responsable_id END"),
                'desasignado_por_id' => DB::raw("CASE WHEN {$reemplazado} THEN {$actorId} ELSE desasignado_por_id END"),
                'desasignado_en' => DB::raw("CASE WHEN {$reemplazado} THEN {$fechaSql} ELSE desasignado_en END"),
                'asignado_por_id' => DB::raw("CASE WHEN {$mismoResponsable} THEN asignado_por_id ELSE {$actorId} END"),
                'asignado_en' => DB::raw("CASE WHEN {$mismoResponsable} THEN asignado_en ELSE {$fechaSql} END"),
                'updated_at' => $fecha,
                'responsable_id' => $responsableId,
            ]);
        });

        abort_unless($actualizado, 409, 'El reclamo ya no está pendiente o ya tiene responsable.');

        return $this->respuesta($reclamo->fresh(['estado', 'responsable']));
    }

    public function comenzar(Request $request, Reclamo $reclamo): JsonResponse
    {
        $datos = $request->validate([
            'observacion' => ['nullable', 'string', 'max:5000'],
            'visibilidad' => ['sometimes', Rule::in(['publica', 'interna'])],
        ]);
        $actor = $request->user();
        $pendiente = EstadoReclamo::where('nombre', 'pendiente')->firstOrFail();
        $enProceso = EstadoReclamo::where('nombre', 'en_proceso')->firstOrFail();

        DB::transaction(function () use ($reclamo, $actor, $datos, $pendiente, $enProceso) {
            $actualizado = Reclamo::whereKey($reclamo->id)
                ->where('estado_id', $pendiente->id)
                ->where('responsable_id', $actor->id)
                ->update(['estado_id' => $enProceso->id, 'updated_at' => now()]);
            abort_unless($actualizado, 409, 'El reclamo debe estar pendiente y asignado a vos para comenzar el trabajo.');

            $reclamo->historialEstados()->create([
                'estado_id' => $enProceso->id,
                'usuario_id' => $actor->id,
                'observacion' => $datos['observacion'] ?? null,
                'visibilidad' => $datos['visibilidad'] ?? 'publica',
                'created_at' => now(),
            ]);
        });

        return $this->respuesta($reclamo->fresh(['estado', 'responsable']));
    }

    public function finalizar(Request $request, Reclamo $reclamo): JsonResponse
    {
        $datos = $request->validate([
            'observacion' => ['required', 'string', 'max:5000'],
            'visibilidad' => ['sometimes', Rule::in(['publica', 'interna'])],
        ]);
        $enProceso = EstadoReclamo::where('nombre', 'en_proceso')->firstOrFail();
        $resuelto = EstadoReclamo::where('nombre', 'resuelto')->firstOrFail();
        DB::transaction(function () use ($request, $reclamo, $datos, $enProceso, $resuelto): void {
            $query = Reclamo::whereKey($reclamo->id)->where('estado_id', $enProceso->id);
            if ($request->user()->rol === 'empleado') {
                $query->where('responsable_id', $request->user()->id);
            }
            abort_unless($query->update(['estado_id' => $resuelto->id, 'updated_at' => now()]), 409, 'El reclamo debe estar en proceso y asignado a vos.');
            $reclamo->historialEstados()->create([
                'estado_id' => $resuelto->id,
                'usuario_id' => $request->user()->id,
                'observacion' => $datos['observacion'],
                'visibilidad' => $datos['visibilidad'] ?? 'publica',
                'created_at' => now(),
            ]);
        });
        return $this->respuesta($reclamo->fresh(['estado', 'responsable']));
    }

    public function desasignar(Request $request, Reclamo $reclamo): JsonResponse
    {
        $pendiente = EstadoReclamo::where('nombre', 'pendiente')->firstOrFail();
        $actualizado = Reclamo::whereKey($reclamo->id)
            ->where('estado_id', $pendiente->id)
            ->whereNotNull('responsable_id')
            ->update([
                'ultimo_responsable_id' => DB::raw('responsable_id'),
                'desasignado_por_id' => $request->user()->id,
                'desasignado_en' => now(),
                'asignado_por_id' => null,
                'asignado_en' => null,
                'updated_at' => now(),
                'responsable_id' => null,
            ]);

        abort_unless($actualizado, 409, 'El reclamo debe estar pendiente y asignado para desasignarlo.');

        return $this->respuesta($reclamo->fresh(['estado', 'responsable']));
    }

    public function rechazar(Request $request, Reclamo $reclamo): JsonResponse
    {
        $datos = $request->validate([
            'observacion' => ['required', 'string', 'max:5000'],
            'es_falso' => ['required', 'boolean'],
        ]);
        abort_if($request->user()->rol === 'empleado' && ! $datos['es_falso'], 403, 'Solo podés rechazar reclamos falsos.');
        $estadosActivos = EstadoReclamo::whereIn('nombre', ['pendiente', 'en_proceso'])->pluck('id');
        $rechazado = EstadoReclamo::where('nombre', 'rechazado')->firstOrFail();

        DB::transaction(function () use ($request, $reclamo, $datos, $estadosActivos, $rechazado): void {
            $query = Reclamo::whereKey($reclamo->id)->whereIn('estado_id', $estadosActivos);
            if ($request->user()->rol === 'empleado') {
                $query->where('responsable_id', $request->user()->id);
            }
            $actualizado = $query->update(['estado_id' => $rechazado->id, 'updated_at' => now()]);
            abort_unless($actualizado, 409, 'Solo se pueden rechazar reclamos pendientes o en proceso.');

            $reclamo->historialEstados()->create([
                'estado_id' => $rechazado->id,
                'usuario_id' => $request->user()->id,
                'observacion' => $datos['observacion'],
                'visibilidad' => 'publica',
                'created_at' => now(),
            ]);

            if ($datos['es_falso']) {
                $usuario = User::whereKey($reclamo->usuario_id)->lockForUpdate()->firstOrFail();
                Sancion::create(['usuario_id' => $usuario->id, 'reclamo_id' => $reclamo->id]);
                // Cada reclamo falso suspende 30 días; nunca acorta una suspensión más larga en curso.
                $hasta = now()->addDays(Sancion::DIAS_SUSPENSION);
                if ($usuario->suspendido_hasta === null || $usuario->suspendido_hasta->lt($hasta)) {
                    $usuario->suspendido_hasta = $hasta;
                    $usuario->save();
                }
            }
        }, 3);

        return $this->respuesta($reclamo->fresh(['estado', 'responsable']));
    }

    private function respuesta(Reclamo $reclamo): JsonResponse
    {
        return response()->json(['data' => [
            'id' => $reclamo->id,
            'estado' => $reclamo->estado->nombre,
            'responsable' => $reclamo->responsable ? [
                'id' => $reclamo->responsable->id,
                'nombre' => $reclamo->responsable->nombre,
                'apellido' => $reclamo->responsable->apellido,
            ] : null,
            'asignado_por_id' => $reclamo->asignado_por_id,
            'asignado_en' => $reclamo->asignado_en?->toIso8601String(),
        ]]);
    }
}
