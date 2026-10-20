<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Permite continuar solo a usuarios con uno de los roles indicados en la ruta.
 */
class AsegurarRol
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $usuario = $request->user();

        if (! $usuario || ! in_array($usuario->rol, $roles, true)) {
            abort(Response::HTTP_FORBIDDEN, 'No tenés permiso para realizar esta acción.');
        }

        return $next($request);
    }
}
