<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Rechaza las peticiones autenticadas de cuentas desactivadas, aunque conserven un token válido.
 */
class AsegurarCuentaActiva
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()?->activo === false) {
            abort(Response::HTTP_FORBIDDEN, 'La cuenta está desactivada.');
        }

        return $next($request);
    }
}
