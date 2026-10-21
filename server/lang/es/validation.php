<?php

/*
|--------------------------------------------------------------------------
| Mensajes de validación en castellano
|--------------------------------------------------------------------------
|
| Solo se traducen las reglas que usa la API. Las que falten se muestran
| en inglés, el idioma de respaldo configurado en APP_FALLBACK_LOCALE.
|
*/

return [

    'array' => 'El campo :attribute debe ser una lista.',
    'confirmed' => 'La confirmación de :attribute no coincide.',
    'digits_between' => 'El campo :attribute debe tener entre :min y :max dígitos.',
    'email' => 'El campo :attribute debe ser un email válido.',
    'exists' => 'El :attribute seleccionado no existe.',
    'integer' => 'El campo :attribute debe ser un número entero.',
    'max' => [
        'string' => 'El campo :attribute no puede tener más de :max caracteres.',
    ],
    'min' => [
        'string' => 'El campo :attribute debe tener al menos :min caracteres.',
    ],
    'required' => 'El campo :attribute es obligatorio.',
    'string' => 'El campo :attribute debe ser un texto.',
    'unique' => 'El :attribute ya está registrado.',

    'custom' => [
        'email' => [
            'unique' => 'Ya existe una cuenta con ese email.',
        ],
        'dni' => [
            'unique' => 'Ya existe una cuenta con ese DNI.',
        ],
    ],

    'attributes' => [
        'apellido' => 'apellido',
        'dispositivo' => 'dispositivo',
        'dni' => 'DNI',
        'email' => 'email',
        'estados' => 'estados',
        'estados.*' => 'estado',
        'nombre' => 'nombre',
        'password' => 'contraseña',
        'telefono' => 'teléfono',
        'tipos' => 'categorías',
        'tipos.*' => 'categoría',
    ],

];
