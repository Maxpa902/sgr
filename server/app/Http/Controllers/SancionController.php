<?php

namespace App\Http\Controllers;

use App\Http\Resources\SancionResource;
use App\Models\Sancion;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Consulta y revocación de sanciones por parte del admin.
 * Las sanciones se crean al rechazar un reclamo por falso (ReclamoTrabajoController::rechazar).
 */
class SancionController extends Controller
{
    /** Todas las sanciones del usuario (vigentes, vencidas y revocadas), de la más nueva a la más vieja. */
    public function index(User $usuario): JsonResponse
    {
        $sanciones = $usuario->sanciones()
            ->with($this->relaciones())
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->get();

        return SancionResource::collection($sanciones)
            ->additional(['usuario' => $this->resumenUsuario($usuario)])
            ->response();
    }

    /**
     * Revoca una sanción con un motivo obligatorio. La sanción no se borra: queda
     * registrado quién la revocó, cuándo y por qué. Después se recalcula la
     * suspensión con las sanciones que siguen activas: si no queda ninguna, se
     * levanta; si queda otra, dura hasta que termine la más reciente.
     */
    public function revocar(Request $request, Sancion $sancion): JsonResponse
    {
        $datos = $request->validate(
            ['motivo' => ['required', 'string', 'max:1000']],
            ['motivo.required' => 'Escribí el motivo de la revocación.'],
        );
        $admin = $request->user();

        $usuario = DB::transaction(function () use ($sancion, $datos, $admin): User {
            // Bloquear al usuario ordena esta revocación con los rechazos por falso
            // y con otras revocaciones, que también recalculan su suspensión.
            $usuario = User::whereKey($sancion->usuario_id)->lockForUpdate()->firstOrFail();

            $revocada = Sancion::whereKey($sancion->id)
                ->whereNull('revocada_en')
                ->update([
                    'revocada_en' => now(),
                    'revocada_por_id' => $admin->id,
                    'motivo_revocacion' => $datos['motivo'],
                    'updated_at' => now(),
                ]);
            abort_unless($revocada, 409, 'La sanción ya fue revocada.');

            if ($usuario->suspendido_hasta?->isFuture()) {
                $usuario->suspendido_hasta = $usuario->sancionesActivas()->latest()->first()?->terminaEn();
                $usuario->save();
            }

            return $usuario;
        }, 3);

        return (new SancionResource($sancion->fresh($this->relaciones())))
            ->additional(['usuario' => $this->resumenUsuario($usuario)])
            ->response();
    }

    /** @return array<string|int, mixed> */
    private function relaciones(): array
    {
        return [
            // El reclamo se muestra aunque tenga baja lógica, para saber de qué fue la sanción.
            'reclamo' => fn ($query) => $query->withTrashed()->with('tipoReclamo'),
            'revocadaPor',
        ];
    }

    /** @return array<string, mixed> */
    private function resumenUsuario(User $usuario): array
    {
        return [
            'id' => $usuario->id,
            'suspendido_hasta' => $usuario->suspendido_hasta?->toIso8601String(),
        ];
    }
}
