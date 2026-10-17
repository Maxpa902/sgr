# Modelo de datos del MVP

Este documento describe las nueve tablas, sus campos y relaciones. Consultar también las [reglas del sistema](reglas-sistema.md) y la [máquina de estados de reclamos](estados-reclamos.md).

## Tablas

- `users`
- `reclamos`
- `fotos_reclamo`
- `tipos_reclamo`
- `estados_reclamo`
- `comentarios`
- `votos`
- `historial_estados_reclamos`
- `sanciones`

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
| `dni` | `string(20)` | Único; se guarda sin puntos. El registro de vecinos lo exige; en la base es opcional (`nullable`) para las cuentas que no se crean desde el registro, como la del admin |
| `estado_verificacion` | `string(20)` | `no_solicitada`, `pendiente`, `aprobada` o `rechazada`; predeterminado: `no_solicitada`; reservado para la verificación de identidad |
| `metodo_verificacion` | `string(30)` | Opcional (`nullable`); reservado: nombre del proveedor de verificación |
| `referencia_verificacion` | `string(255)` | Opcional (`nullable`); reservado: identificador de la solicitud en el proveedor |
| `identidad_verificada_en` | `timestamp()` | Opcional (`nullable`); reservado: fecha de aprobación de la identidad |
| `rol` | `enum(['ciudadano', 'empleado', 'admin'])` | Predeterminado: `ciudadano`; `ciudadano` es el vecino y `empleado`, el operario |
| `activo` | `boolean()` | Predeterminado: `true` |
| `suspendido_hasta` | `timestamp()` | Opcional (`nullable`); fin de la suspensión por sanciones; la cuenta está suspendida mientras la fecha sea futura |
| `email_verified_at` | `timestamp()` | Opcional (`nullable`); para verificación de correo si se incorpora |
| `remember_token` | `rememberToken()` | Opcional; para la función de recordar sesión de Laravel |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

Los campos de verificación de identidad (`estado_verificacion`, `metodo_verificacion`, `referencia_verificacion` e `identidad_verificada_en`) quedan reservados para una funcionalidad futura y hoy no se usan. Ver [Pendiente a futuro](reglas-sistema.md#pendiente-a-futuro).

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
| `titulo` | `string(150)` | Opcional (`nullable`); si está vacío, se muestra el nombre de la categoría |
| `descripcion` | `text()` | Obligatorio |
| `latitud` | `decimal(10, 7)` | Obligatorio; ubicación en el mapa |
| `longitud` | `decimal(10, 7)` | Obligatorio; ubicación en el mapa |
| `direccion` | `string(255)` | Opcional (`nullable`); referencia textual de la ubicación |
| `es_publico` | `boolean()` | Predeterminado: `true`; reservado para los reclamos privados; hoy todos los reclamos son públicos |
| `deleted_at` | `softDeletes()` | Timestamp opcional (`nullable`); fecha de baja lógica |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

Las fotos se guardan en `fotos_reclamo`; cada reclamo tiene entre una y cinco.

Por ahora todos los reclamos son públicos. Los reclamos privados quedan [pendientes a futuro](reglas-sistema.md#pendiente-a-futuro).

### `fotos_reclamo`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `reclamo_id` | `foreignId()` | Obligatorio; referencia a `reclamos.id` |
| `ruta` | `string(255)` | Obligatorio; ruta o URL de la foto, no el archivo en sí |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

Las fotos se muestran en orden de `id`. Las condiciones de carga y privacidad están en [Fotos de reclamos](reglas-sistema.md#fotos-de-reclamos).

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
| `valor` | `string(20)` | `confirma` o `desmiente`; predeterminado: `confirma` |
| `created_at` | `timestamp()` | Fecha de creación |
| `updated_at` | `timestamp()` | Fecha de última actualización |

Restricción única compuesta sobre `(usuario_id, reclamo_id)`: un usuario solo puede votar una vez cada reclamo. `confirma` indica que el problema es real y `desmiente` que no lo es. Cambiar de opinión actualiza `valor` del mismo registro. Los votos son una señal para priorizar y no cambian el estado del reclamo.

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

El historial no tiene `updated_at` y sus registros son inmutables. Se ordena por `created_at` y, ante fechas iguales, por `id`. `usuario_id = null` representa al sistema; no se necesita un usuario ficticio. Como no hay asignación de reclamos, `usuario_id` es el registro de qué operario trabajó en cada reclamo.

`reclamos.estado_id` guarda el estado actual. Las fechas finales se obtienen del historial, sin campos `resuelto_en` ni `rechazado_en` en `reclamos`. La observación del rechazo usa `observacion`, sin un campo `motivo_rechazo` separado. Las reglas de registro, transacciones y visibilidad están en [Historial y observaciones](estados-reclamos.md#historial-y-observaciones).

### `sanciones`

| Campo | Tipo Laravel | Restricciones / uso |
| --- | --- | --- |
| `id` | `id()` | Clave primaria |
| `usuario_id` | `foreignId()` | Obligatorio; referencia a `users.id` (usuario sancionado); coincide con el creador del reclamo |
| `reclamo_id` | `foreignId()` | Obligatorio y único; referencia a `reclamos.id` (reclamo rechazado por falso) |
| `revocada_en` | `timestamp()` | Opcional (`nullable`); fecha de revocación; vacío mientras la sanción esté vigente |
| `revocada_por_id` | `foreignId()` | Opcional (`nullable`); referencia a `users.id` (admin que la revocó) |
| `motivo_revocacion` | `text()` | Opcional (`nullable`) en la base; la aplicación lo exige al revocar |
| `created_at` | `timestamp()` | Fecha de la sanción |
| `updated_at` | `timestamp()` | Fecha de última actualización |

Un reclamo genera como máximo una sanción. `usuario_id` repite el creador del reclamo para consultar directamente las sanciones de un usuario. Quién rechazó el reclamo y con qué motivo se obtiene del historial. Las sanciones no se borran: revocar completa los tres campos de revocación. Las reglas de strikes y suspensión están en [Sanciones](reglas-sistema.md#sanciones).

## Convenciones estructurales

- La tabla de cuentas conserva el nombre convencional `users` de Laravel; sus campos propios están en español y los campos de autenticación convencionales en inglés.
- `id()` genera una clave primaria entera grande sin signo y autoincremental; `foreignId()` utiliza el mismo tipo compatible.
- `created_at` y `updated_at` se crean con `timestamps()`, excepto el historial, que solo tiene `created_at`.
- Las claves foráneas apuntan explícitamente a las tablas indicadas.
- `softDeletes()` agrega `deleted_at` en `reclamos`; no implica borrar las filas relacionadas. Sus condiciones se documentan en [Edición y eliminación de reclamos](reglas-sistema.md#edición-y-eliminación-de-reclamos).
- Se conservan usuarios y categorías referenciados mediante desactivación, sin eliminar sus relaciones históricas.
- `dni` y `email` son únicos: no puede haber dos cuentas con el mismo valor. `email_verified_at` representa verificación de correo, independiente de la identidad.

## Cardinalidades

| Relación | Cardinalidad |
| --- | --- |
| Usuario → reclamos creados | 1-M |
| Tipo de reclamo → reclamos | 1-M |
| Estado de reclamo → reclamos | 1-M |
| Usuario → comentarios | 1-M |
| Reclamo → comentarios | 1-M |
| Usuario → votos | 1-M |
| Reclamo → votos | 1-M |
| Reclamo → historial de estados | 1-M |
| Estado de reclamo → registros del historial | 1-M |
| Usuario → cambios de estado realizados | 1-M |
| Reclamo → fotos | 1-M |
| Usuario → sanciones recibidas | 1-M |
| Usuario admin → sanciones revocadas | 1-M |
| Reclamo → sanción | 1-0..1 |

`1-M` y `M-1` representan la misma relación vista desde lados opuestos.

Cada reclamo tiene un usuario creador, un tipo y un estado. Cada registro del historial pertenece a un reclamo y un estado, y tiene cero o un usuario autor: sin usuario, el cambio corresponde al sistema.

Del lado de muchos puede haber cero registros: por ejemplo, un reclamo puede no tener comentarios ni votos. La excepción son las fotos: la aplicación exige al menos una por reclamo.

La relación entre usuarios y reclamos al votar es **M-M**, resuelta mediante la tabla `votos`. Los comentarios también vinculan muchos usuarios con muchos reclamos mediante la tabla `comentarios`.

La única relación **1-1** es la de reclamo y sanción, y es opcional: un reclamo tiene cero o una sanción, garantizado por la restricción única sobre `sanciones.reclamo_id`.
