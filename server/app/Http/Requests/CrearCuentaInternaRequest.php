<?php

namespace App\Http\Requests;

use Illuminate\Validation\Rule;

class CrearCuentaInternaRequest extends RegistrarUsuarioRequest
{
    public function rules(): array
    {
        return array_merge(parent::rules(), [
            'rol' => ['required', Rule::in(['empleado', 'admin'])],
        ]);
    }
}
