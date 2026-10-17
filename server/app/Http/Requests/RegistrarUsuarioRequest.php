<?php

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class RegistrarUsuarioRequest extends FormRequest
{
    /**
     * Guarda el DNI sin puntos, espacios ni guiones, para que "30.111.222" y
     * "30111222" se reconozcan como el mismo documento.
     */
    protected function prepareForValidation(): void
    {
        if (is_string($this->input('dni'))) {
            $this->merge(['dni' => preg_replace('/[\s.\-]/', '', $this->input('dni'))]);
        }
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:255'],
            'apellido' => ['required', 'string', 'max:100'],
            'dni' => ['required', 'string', 'digits_between:7,8', Rule::unique('users', 'dni')],
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users', 'email')],
            'password' => ['required', 'string', 'confirmed', Password::defaults()],
            'telefono' => ['nullable', 'string', 'max:30'],
            'dispositivo' => ['nullable', 'string', 'max:100'],
        ];
    }
}
