# Modelo de datos del MVP

Este documento describe las ocho tablas, sus campos y relaciones. Consultar también las [reglas del sistema](reglas-sistema.md) y la [máquina de estados de reclamos](estados-reclamos.md).

## Tablas

- `users`
- `reclamos`
- `tipos_reclamo`
- `estados_reclamo`
- `comentarios`
- `votos`
- `historial_estados_reclamos`
- `cuadrillas`

## Campos y tipos

Los campos propios de la aplicación están en español. Se conservan en inglés los campos convencionales de Laravel. Los tipos indicados corresponden a métodos de migraciones de Laravel.

### `users`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `nombre` | `string(255)` | Obligatorio; reemplaza el campo `name` convencional inicial de Laravel |
| `apellido` | `string(100)` | Obligatorio |
| `email` | `string(255)` | Obligatorio y único |
| `password` | `string(255)` | Obligatorio; guardar el hash de la contraseña |
| `telefono` | `string(30)` | Opcional (`nullable`) |
| `dni` | `string(20)` | Opcional (`nullable`); documento declarado para solicitar la verificación |
| `estado_verificacion` | `string(20)` | `no_solicitada`, `pendiente`, `aprobada` o `rechazada`; predeterminado: `no_solicitada` |
| `metodo_verificacion` | `string(30)` | Opcional (`nullable`); `simulacion` o nombre del proveedor utilizado |
| `referencia_verificacion` | `string(255)` | Opcional (`nullable`); identificador de la solicitud en el proveedor; no se necesita en la simulación propia |
| `identidad_verificada_en` | `timestamp()` | Opcional (`nullable`); fecha de aprobación; permanece vacío mientras no esté aprobada |
| `rol` | `enum(['ciudadano', 'empleado', 'admin'])` | Predeterminado: `ciudadano` |
| `cuadrilla_id` | `foreignId()` | Opcional (`nullable`); referencia a `cuadrillas.id`; como máximo una cuadrilla por usuario |
| `activo` | `boolean()` | Predeterminado: `true` |
| `email_verified_at` | `timestamp()` | Opcional (`nullable`); para verificación de correo si se incorpora |
| `remember_token` | `rememberToken()` | Opcional; para la función de recordar sesión de Laravel |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

### `tipos_reclamo`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `nombre` | `string(100)` | Obligatorio y único; ejemplos iniciales: energía eléctrica, alumbrado público, agua potable, cloacas y saneamiento, telefonía e internet |
| `descripcion` | `text()` | Opcional (`nullable`) |
| `activo` | `boolean()` | Predeterminado: `true` |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

### `estados_reclamo`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `nombre` | `string(50)` | Obligatorio y único: `pendiente`, `en_proceso`, `resuelto` o `rechazado` |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

### `reclamos`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `usuario_id` | `foreignId()` | Obligatorio; referencia a `users.id` (creador) |
| `tipo_reclamo_id` | `foreignId()` | Obligatorio; referencia a `tipos_reclamo.id` |
| `estado_id` | `foreignId()` | Obligatorio; referencia a `estados_reclamo.id`; inicialmente pendiente |
| `empleado_id` | `foreignId()` | Opcional (`nullable`); referencia a `users.id` (empleado asignado) |
| `cuadrilla_id` | `foreignId()` | Opcional (`nullable`); referencia a `cuadrillas.id` (equipo asignado) |
| `titulo` | `string(150)` | Obligatorio |
| `descripcion` | `text()` | Obligatorio |
| `foto` | `string(255)` | Obligatorio; ruta o URL de la foto, no el archivo en sí |
| `latitud` | `decimal(10, 7)` | Obligatorio; ubicación en el mapa |
| `longitud` | `decimal(10, 7)` | Obligatorio; ubicación en el mapa |
| `direccion` | `string(255)` | Opcional (`nullable`); referencia textual de la ubicación |
| `es_publico` | `boolean()` | Predeterminado: `true`; determina la visibilidad del reclamo |
| `deleted_at` | `softDeletes()` | Timestamp opcional (`nullable`); fecha de baja lógica |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

Para este MVP se guarda una sola foto por reclamo.

En un reclamo público, los ciudadanos pueden consultarlo y participar según las reglas del sistema. En uno privado, solo pueden consultarlo su creador y el personal autorizado para gestionarlo; únicamente el creador puede votar y comentar. La visibilidad de observaciones del historial se rige además por sus reglas específicas.

### `comentarios`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `reclamo_id` | `foreignId()` | Obligatorio; referencia a `reclamos.id` |
| `usuario_id` | `foreignId()` | Obligatorio; referencia a `users.id` |
| `contenido` | `text()` | Obligatorio |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

La edición actualiza `updated_at`. La eliminación borra el registro; no se guarda un historial de ediciones ni bajas lógicas de comentarios. Los permisos y límites se definen en [Comentarios y votos](reglas-sistema.md#comentarios-y-votos).

### `votos`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `reclamo_id` | `foreignId()` | Obligatorio; referencia a `reclamos.id` |
| `usuario_id` | `foreignId()` | Obligatorio; referencia a `users.id` |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

Restricción única compuesta sobre `(usuario_id, reclamo_id)`: un usuario solo puede votar una vez cada reclamo. Cada voto representa apoyo; no necesita un campo de valor.

### `historial_estados_reclamos`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `reclamo_id` | `foreignId()` | Obligatorio; referencia a `reclamos.id` |
| `estado_id` | `foreignId()` | Obligatorio; referencia a `estados_reclamo.id` (estado al que pasó) |
| `usuario_id` | `foreignId()` | Opcional (`nullable`); referencia a `users.id` (autor del cambio); `null` indica un cambio realizado por el sistema |
| `observacion` | `text()` | Opcional (`nullable`) en la base; la aplicación la exige al resolver o rechazar |
| `visibilidad` | `string(20)` | `publica` o `interna`; predeterminado: `publica`; determina quién ve la observación |
| `created_at` | `timestamp()` | Fecha en que se registró el cambio |

El historial no tiene `updated_at` y sus registros son inmutables. Se ordena por `created_at` y, ante fechas iguales, por `id`. `usuario_id = null` representa al sistema; no se necesita un usuario ficticio.

`reclamos.estado_id` guarda el estado actual. Las fechas finales se obtienen del historial, sin campos `resuelto_en` ni `rechazado_en` en `reclamos`. La observación del rechazo usa `observacion`, sin un campo `motivo_rechazo` separado. Las reglas de registro, transacciones y visibilidad están en [Historial y observaciones](estados-reclamos.md#historial-y-observaciones).

### `cuadrillas`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `nombre` | `string(100)` | Obligatorio y único |
| `activo` | `boolean()` | Predeterminado: `true` |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

La pertenencia se guarda en `users.cuadrilla_id`: un usuario puede estar en cero o una cuadrilla y una cuadrilla puede tener muchos usuarios. Para este MVP, sus integrantes son usuarios con rol empleado. No se necesita una tabla intermedia.

Un reclamo puede asignarse a una cuadrilla mediante `reclamos.cuadrilla_id`. `empleado_id` permite indicar un responsable individual opcional; si ambos campos están completos, el empleado debe pertenecer a la cuadrilla asignada.

## Convenciones estructurales

- La tabla de cuentas conserva el nombre convencional `users` de Laravel; sus campos propios están en español y los campos de autenticación convencionales en inglés.
- `id()` genera una clave primaria entera grande sin signo y autoincremental; `foreignId()` utiliza el mismo tipo compatible.
- `created_at` y `updated_at` se crean con `timestamps()`, excepto el historial, que solo tiene `created_at`.
- Las claves foráneas apuntan explícitamente a las tablas indicadas.
- `softDeletes()` agrega `deleted_at` en `reclamos`; no implica borrar las filas relacionadas. Sus condiciones se documentan en [Edición y eliminación de reclamos](reglas-sistema.md#edición-y-eliminación-de-reclamos).
- Se conservan usuarios, categorías y cuadrillas referenciados mediante desactivación, sin eliminar sus relaciones históricas.
- `dni` no tiene restricción de unicidad ni vincula cuentas. `email_verified_at` representa verificación de correo, independiente de la identidad.

## Cardinalidades

| Relación | Cardinalidad |
| --- | --- |
| Usuario → reclamos creados | 1-M |
| Usuario empleado → reclamos asignados | 1-M |
| Tipo de reclamo → reclamos | 1-M |
| Estado de reclamo → reclamos | 1-M |
| Usuario → comentarios | 1-M |
| Reclamo → comentarios | 1-M |
| Usuario → votos | 1-M |
| Reclamo → votos | 1-M |
| Reclamo → historial de estados | 1-M |
| Estado de reclamo → registros del historial | 1-M |
| Usuario → cambios de estado realizados | 1-M |
| Cuadrilla → usuarios integrantes | 1-M |
| Cuadrilla → reclamos asignados | 1-M |

`1-M` y `M-1` representan la misma relación vista desde lados opuestos.

Cada reclamo tiene un usuario creador, un tipo y un estado. Puede tener cero o un empleado asignado y cero o una cuadrilla asignada. El empleado es un usuario con rol empleado.

Cada usuario pertenece a cero o una cuadrilla. Cada registro del historial pertenece a un reclamo y un estado, y tiene cero o un usuario autor: sin usuario, el cambio corresponde al sistema.

Del lado de muchos puede haber cero registros: por ejemplo, un reclamo puede no tener comentarios ni votos.

La relación entre usuarios y reclamos al votar es **M-M**, resuelta mediante la tabla `votos`. Los comentarios también vinculan muchos usuarios con muchos reclamos mediante la tabla `comentarios`.

Por ahora no hay relaciones **1-1**.
