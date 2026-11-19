<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ActualizarPerfilRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('dni') && $this->dni !== null) {
            $dniNormalizado = preg_replace('/[\s.\-]/', '', (string) $this->dni);
            $this->merge([
                'dni' => $dniNormalizado === '' ? null : $dniNormalizado,
            ]);
        }

        if ($this->has('email') && is_string($this->email)) {
            $this->merge([
                'email' => mb_strtolower(trim($this->email)),
            ]);
        }

        // Si el formulario manda password vacío, lo quitamos para no pisar la clave actual
        if ($this->has('password') && ($this->password === null || $this->password === '')) {
            $this->request->remove('password');
            $this->request->remove('password_confirmation');
            $this->request->remove('password_actual');
        }
    }

    public function rules(): array
    {
        $usuario = $this->user();
        $dniRequerido = $usuario->rol === 'ciudadano' ? 'required' : 'nullable';

        return [
            'nombre' => ['sometimes', 'required', 'string', 'max:255'],
            'apellido' => ['sometimes', 'required', 'string', 'max:100'],
            'email' => [
                'sometimes',
                'required',
                'string',
                'email',
                'max:255',
                Rule::unique('users', 'email')->ignore($usuario->id),
            ],
            'telefono' => ['sometimes', 'nullable', 'string', 'max:30'],
            'dni' => [
                'sometimes',
                $dniRequerido,
                'regex:/^\d{7,8}$/',
                Rule::unique('users', 'dni')->ignore($usuario->id),
            ],
            'password_actual' => ['required_with:password', 'string', 'current_password'],
            'password' => ['sometimes', 'required', 'string', 'min:8', 'confirmed'],
        ];
    }

    public function messages(): array
    {
        return [
            'dni.regex' => 'El DNI debe tener 7 u 8 dígitos numéricos.',
            'dni.unique' => 'Ya existe una cuenta registrada con ese DNI.',
            'email.unique' => 'Ya existe una cuenta registrada con ese email.',
            'password_actual.current_password' => 'La contraseña actual no es correcta.',
            'password_actual.required_with' => 'Debés ingresar tu contraseña actual para cambiarla.',
        ];
    }
}