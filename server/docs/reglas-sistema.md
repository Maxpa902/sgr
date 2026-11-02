# Reglas del sistema

Este documento reúne permisos y reglas de negocio del MVP. Consultar también el [modelo de datos](modelo-datos.md) y la [máquina de estados de reclamos](estados-reclamos.md).

## Roles

Hay tres roles. Todos usan la misma app móvil, con las pantallas habilitadas según el rol.

| Rol | Valor en `users.rol` | Qué hace |
| --- | --- | --- |
| Vecino | `ciudadano` | Carga reclamos, vota y comenta |
| Operario | `empleado` | Atiende los reclamos y cambia su estado |
| Admin | `admin` | Administra cuentas, categorías y sanciones |

## Registro

- Cualquier persona puede crear una cuenta de vecino con nombre, apellido, DNI, email, contraseña y, opcionalmente, teléfono.
- El **DNI es obligatorio** y debe tener 7 u 8 dígitos. Se aceptan puntos, espacios o guiones al escribirlo, pero se guarda solo con los números.
- **No puede haber dos cuentas con el mismo DNI ni con el mismo email.** Se comprueba al enviar el registro; no hay una consulta previa que permita averiguar si un DNI está registrado.
- El DNI se declara pero no se verifica: comprobar que pertenece a quien se registra queda [pendiente a futuro](#pendiente-a-futuro). Es un dato personal y la API no lo muestra a otros usuarios.

## Vecinos

- Pueden consultar el mapa, los reclamos, sus votos y sus comentarios.
- Pueden cargar reclamos: eligen la categoría y escriben una descripción. El **título es opcional**; si no lo escriben, se muestra el nombre de la categoría.
- Pueden tener como máximo **tres reclamos propios activos**. Son activos los reclamos en `pendiente` o `en_proceso` que no tengan baja lógica.
- Mientras estén suspendidos, solo conservan las funciones de consulta. Ver [Sanciones](#sanciones).

## Comentarios y votos

Estas acciones requieren no estar suspendido y un reclamo sin baja lógica.

- En reclamos de otros usuarios en `pendiente` o `en_proceso`, pueden votar `confirma` (el problema es real) o `desmiente` (no lo es). El creador no vota su propio reclamo. Solo puede existir un voto por combinación de usuario y reclamo. Mientras el reclamo siga activo, pueden cambiar el valor, quitar el voto y volver a votar, sin duplicar votos.
- Los votos son una señal para el personal, no una decisión automática: ninguna cantidad de votos cambia el estado del reclamo. Las vistas de trabajo pueden destacar y ordenar los reclamos por cantidad de confirmaciones para priorizarlos.
- Pueden tener hasta **tres comentarios existentes por usuario por reclamo**, incluido uno propio, únicamente en `pendiente` o `en_proceso`. Pueden editar o eliminar solamente sus propios comentarios mientras el reclamo siga en uno de esos estados y no tenga baja lógica. Editar no consume otro lugar; eliminar libera un lugar para un nuevo comentario.
- En `resuelto` o `rechazado` se conservan los comentarios y votos existentes. Se pueden consultar, pero no se puede crear, editar o eliminar comentarios ni dar o quitar votos.

## Visibilidad de reclamos

- Por ahora todos los reclamos son públicos: aparecen en el mapa y cualquier usuario con sesión iniciada puede verlos. Los reclamos privados quedan [pendientes a futuro](#pendiente-a-futuro).
- Las observaciones internas del historial solo las ven operarios y administradores. Las públicas las ve cualquier usuario.

## Mapa

- El mapa cubre **Comodoro Rivadavia (incluida Caleta Córdova) y Rada Tilly**, y no permite moverse fuera de esa zona.
- Al abrirlo muestra los reclamos activos (`pendiente` y `en_proceso`). Los filtros permiten sumar los `resuelto` y elegir categorías. La app no muestra los `rechazado` en el mapa.
- Cada pin indica el estado con su color y la categoría con su ícono. Los reclamos con **cinco o más confirmaciones** se destacan con un pin más grande, y el número de confirmaciones se ve sobre el pin.
- Los pines muy cercanos se agrupan en una burbuja con la cantidad de reclamos, por ejemplo cuando muchos vecinos reportan el mismo corte de luz.
- El botón "Mi ubicación" usa el GPS del celular con permiso del usuario. La ubicación no se envía al server: solo centra el mapa.

## Edición y eliminación de reclamos

Crear y editar requieren no estar suspendido.

- Pueden editar el título, la descripción, las fotos y la ubicación de un reclamo propio únicamente mientras esté `pendiente` y sin baja lógica. La edición no permite cambiar el creador ni el estado.
- Pueden eliminar únicamente un reclamo propio que siga `pendiente` y nunca haya cambiado de estado. El registro inicial del historial no cuenta como cambio de estado.
- La eliminación es una baja lógica mediante `deleted_at`. El reclamo deja de aparecer en el mapa y en las consultas de los vecinos, no admite edición del reclamo ni cambios en votos o comentarios y no cuenta para el límite de activos. Se conservan sus datos, historial, votos y comentarios para la gestión administrativa.

## Fotos de reclamos

- Cada reclamo tiene entre **una y cinco fotos**, guardadas en `fotos_reclamo`. Las carga el creador al crear el reclamo o al editarlo bajo las condiciones anteriores; al editar puede agregar o quitar fotos sin quedar con menos de una.
- La app permite sacar las fotos con la cámara o elegirlas de la galería. Las imágenes viejas o descargadas de internet se controlan con los votos `desmiente` de la comunidad y, si el reclamo resulta falso, con las [sanciones](#sanciones).
- Por privacidad (Ley 25.326), el backend elimina los metadatos EXIF de cada foto antes de guardarla, incluida la ubicación GPS del archivo. La ubicación del reclamo es solo la indicada en el mapa.
- Las fotos se conservan ante una baja lógica, igual que el resto de los datos del reclamo.

## Sanciones

- Un reclamo se marca como **falso** al rechazarlo. Puede hacerlo el admin o cualquier operario. Solo en ese caso se crea una sanción para el creador, en la misma transacción que el cambio de estado. Un rechazo por otros motivos, por ejemplo porque el problema no corresponde a la cooperativa, no sanciona y solo lo hace el admin.
- Una sanción está vigente si no fue revocada y tiene menos de **180 días**.
- Al registrar una sanción, si el usuario acumula **tres o más sanciones vigentes**, queda suspendido por **30 días**: se completa `suspendido_hasta`. No se bloquea al primer error.
- Un usuario suspendido conserva las funciones de consulta, pero no puede crear o editar reclamos, votar ni crear, editar o eliminar comentarios. La suspensión termina sola al pasar la fecha. No afecta las funciones de trabajo de un operario.
- El admin puede revocar una sanción indicando un motivo obligatorio. La sanción se conserva con la fecha, el admin y el motivo de la revocación. Si después de revocarla quedan menos de tres sanciones vigentes, se levanta la suspensión en curso.
- Los votos `desmiente` de la comunidad no generan sanciones por sí mismos.
- Por ahora los plazos y el umbral son fijos. Pueden pasar a configuración si hace falta ajustarlos.

## Operarios

- Usan la misma app móvil que los vecinos, con las vistas de trabajo habilitadas por su rol.
- Pueden consultar todos los reclamos desde la vista de trabajo, con su historial y las observaciones internas.
- Un operario puede tomar para sí un reclamo pendiente sin responsable. El admin puede asignar o reasignar un reclamo pendiente a un operario activo o a sí mismo. La asignación no cambia el estado; el responsable debe iniciar el trabajo para pasar a `en_proceso`. El historial registra cada transición de estado.
- Pueden rechazar un reclamo únicamente marcándolo como falso, lo que genera una [sanción](#sanciones) para su creador. No pueden revocar sanciones.
- Cuando usan las funciones de vecino (cargar reclamos, votar o comentar), se aplican las mismas reglas y límites que a cualquier vecino.

## Administradores

- Usan una cuenta exclusiva e independiente, con su propio email y contraseña, sin vínculo con una cuenta personal. El rol admin no otorga automáticamente las funciones de vecino.
- Hacen todo desde la misma app móvil, con las vistas de administración habilitadas por su rol.
- Pueden consultar todos los reclamos, incluidos los dados de baja, con su historial.
- Gestionan las categorías y las cuentas de operarios.
- Pueden gestionar cambios de estado según [Transiciones](estados-reclamos.md#transiciones). No hay edición libre del catálogo de estados.
- Al rechazar un reclamo, indican si era falso, y pueden consultar y revocar sanciones según [Sanciones](#sanciones).
- Pueden desactivar y reactivar cuentas, excepto desactivar su propia cuenta o dejar al sistema sin un administrador activo. No eliminan usuarios referenciados ni modifican o borran el historial.

## Reglas comunes

- El backend comprueba en cada petición que la cuenta esté activa, sus permisos según el rol y, cuando corresponda, la suspensión. Una cuenta desactivada no puede usar las funciones autenticadas.
- El registro público y la edición del perfil no permiten concederse roles.
- El registro de cambios y las posibles acciones del sistema siguen [Historial y observaciones](estados-reclamos.md#historial-y-observaciones).
- Desactivar usuarios o categorías conserva sus registros y relaciones históricas. Las categorías desactivadas no se ofrecen para crear reclamos nuevos.

## Reclamos potencialmente duplicados: mejora futura

Queda pendiente investigar un criterio para detectar reclamos que describen el mismo problema. Una primera aproximación puede comparar reclamos activos por tipo y cercanía geográfica; la descripción y las fotos podrían aportar criterios adicionales. Todavía no se define distancia, algoritmo ni implementación. Esta versión no bloquea ni identifica automáticamente duplicados.

## Pendiente a futuro

Ideas que se sacaron del MVP para pensarlas mejor. Quedan documentadas para no perderlas.

### Verificación de identidad

La idea es comprobar que cada cuenta pertenece a una persona real, por ejemplo validando el DNI con un proveedor externo, antes de habilitarla para cargar reclamos. Se descartó la simulación con resultado aleatorio. Hoy el DNI se pide al registrarse y no puede repetirse, pero no se verifica. Las columnas `estado_verificacion`, `metodo_verificacion`, `referencia_verificacion` e `identidad_verificada_en` de `users` quedan reservadas para esto; hoy no se usan ni bloquean ninguna acción.

### Cuadrillas

La asignación actual es individual. Agrupar operarios en equipos (cuadrillas) queda pendiente para más adelante.

### Reclamos privados

La idea es permitir reclamos que solo vean su creador y el personal, por ejemplo un problema dentro de un domicilio. La columna `reclamos.es_publico` queda reservada para esto, con valor `true` en todos los reclamos; las consultas del mapa ya filtran por ella.
