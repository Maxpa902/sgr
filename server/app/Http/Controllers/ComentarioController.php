<?php

namespace App\Http\Controllers;

use App\Http\Resources\ComentarioResource;
use App\Models\Comentario;
use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;

/**
 * Comentarios de los reclamos. Cualquier usuario con sesión los lee; vecinos y
 * operarios no suspendidos escriben hasta tres por reclamo, solo mientras el
 * reclamo está pendiente o en proceso. Cada uno edita y borra solo los suyos.
 */
class ComentarioController extends Controller
{
    /** @var array<string, array<int, string>> */
    private const REGLAS = ['contenido' => ['required', 'string', 'max:1000']];

    /** @var array<string, string> */
    private const MENSAJES = [
        'contenido.required' => 'Escribí el comentario.',
        'contenido.max' => 'El comentario puede tener hasta 1000 caracteres.',
    ];

    /**
     * Los comentarios del más viejo al más nuevo. En `meta` indica cuántos más
     * puede escribir el usuario, si no puede escribir otro por qué, y si puede
     * editar o borrar los suyos (para eso no cuenta el límite).
     */
    public function index(Request $request, Reclamo $reclamo): JsonResponse
    {
        $usuario = $request->user();
        abort_unless($this->puedeVer($reclamo, $usuario), 404);

        $comentarios = $reclamo->comentarios()
            ->with('usuario:id,nombre,apellido')
            ->orderBy('created_at')
            ->orderBy('id')
            ->get();
        $propios = $comentarios->where('usuario_id', $usuario->id)->count();

        return ComentarioResource::collection($comentarios)
            ->additional(['meta' => [
                'disponibles' => max(0, Comentario::LIMITE_POR_USUARIO - $propios),
                'motivo_bloqueo' => $this->bloqueo($reclamo, $usuario, $propios)[1] ?? null,
                'puede_modificar_propios' => $this->bloqueo($reclamo, $usuario) === null,
            ]])
            ->response();
    }

    public function store(Request $request, Reclamo $reclamo): JsonResponse
    {
        $datos = $request->validate(self::REGLAS, self::MENSAJES);

        return DB::transaction(function () use ($request, $reclamo, $datos): JsonResponse {
            // Bloquear el reclamo ordena los comentarios simultáneos del mismo usuario,
            // así no se pasa del límite contando a la vez.
            $reclamo = Reclamo::whereKey($reclamo->id)->lockForUpdate()->firstOrFail();
            $usuario = User::whereKey($request->user()->id)->lockForUpdate()->firstOrFail();
            abort_unless($this->puedeVer($reclamo, $usuario), 404);

            $propios = $reclamo->comentarios()->where('usuario_id', $usuario->id)->count();
            $this->cortarSiEstaBloqueado($reclamo, $usuario, $propios);

            $comentario = $reclamo->comentarios()->create([
                'usuario_id' => $usuario->id,
                'contenido' => $datos['contenido'],
            ]);

            return (new ComentarioResource($comentario->load('usuario')))
                ->response()
                ->setStatusCode(201);
        });
    }

    public function update(Request $request, Comentario $comentario): ComentarioResource
    {
        $datos = $request->validate(self::REGLAS, self::MENSAJES);

        DB::transaction(function () use ($request, $comentario, $datos): void {
            $this->prepararCambio($comentario, $request->user());
            $comentario->update(['contenido' => $datos['contenido']]);
        });

        return new ComentarioResource($comentario->fresh('usuario'));
    }

    public function destroy(Request $request, Comentario $comentario): Response
    {
        DB::transaction(function () use ($request, $comentario): void {
            $this->prepararCambio($comentario, $request->user());
            $comentario->delete();
        });

        return response()->noContent();
    }

    /**
     * Antes de editar o borrar: bloquea el reclamo y el usuario, y corta si el
     * comentario no es suyo o si ya no se puede modificar.
     */
    private function prepararCambio(Comentario $comentario, User $actor): void
    {
        $reclamo = Reclamo::whereKey($comentario->reclamo_id)->lockForUpdate()->first();
        abort_if($reclamo === null, 404);
        $usuario = User::whereKey($actor->id)->lockForUpdate()->firstOrFail();

        abort_unless(
            (int) $comentario->usuario_id === (int) $usuario->id,
            403,
            'Solo podés modificar tus propios comentarios.',
        );
        $this->cortarSiEstaBloqueado($reclamo, $usuario);
    }

    private function cortarSiEstaBloqueado(Reclamo $reclamo, User $usuario, ?int $propios = null): void
    {
        if ($bloqueo = $this->bloqueo($reclamo, $usuario, $propios)) {
            abort($bloqueo[0], $bloqueo[1]);
        }
    }

    /**
     * Por qué el usuario no puede escribir en el reclamo, con su código HTTP, o
     * `null` si puede. El límite solo cuenta al crear: editar no ocupa otro lugar.
     *
     * @return array{int, string}|null
     */
    private function bloqueo(Reclamo $reclamo, User $usuario, ?int $propios = null): ?array
    {
        return match (true) {
            $usuario->rol === 'admin' => [403, 'Los administradores no comentan reclamos.'],
            (bool) $usuario->suspendido_hasta?->isFuture() => [403, 'Tu cuenta está suspendida y no puede comentar.'],
            ! in_array($reclamo->estado->nombre, EstadoReclamo::ACTIVOS, true) => [409, 'El reclamo ya finalizó: los comentarios están cerrados.'],
            $propios !== null && $propios >= Comentario::LIMITE_POR_USUARIO => [409, 'Ya tenés 3 comentarios en este reclamo. Borrá uno para escribir otro.'],
            default => null,
        };
    }

    /** Los reclamos privados solo los ven su creador y el personal. */
    private function puedeVer(Reclamo $reclamo, User $usuario): bool
    {
        return $reclamo->es_publico
            || (int) $reclamo->usuario_id === (int) $usuario->id
            || in_array($usuario->rol, ['admin', 'empleado'], true);
    }
}
