# Reglas del sistema

Este documento reúne permisos y reglas de negocio del MVP. Consultar también el [modelo de datos](modelo-datos.md) y la [máquina de estados de reclamos](estados-reclamos.md).

## Ciudadanos sin identidad verificada

- Pueden consultar el mapa, los reclamos visibles, sus votos y sus comentarios.
- Pueden solicitar la verificación de identidad.
- No pueden crear o editar reclamos, votar ni crear, editar o eliminar comentarios. Se considera sin verificar cualquier estado de verificación distinto de `aprobada`.

## Ciudadanos con identidad verificada

- Tienen todas las funciones de consulta anteriores.
- Pueden tener como máximo **tres reclamos propios activos**. Son activos los reclamos en `pendiente` o `en_proceso` que no tengan baja lógica.

## Comentarios y votos

Estas acciones requieren identidad aprobada y un reclamo visible sin baja lógica.

- Pueden dar un like a cualquier reclamo visible en `pendiente` o `en_proceso`, incluido uno propio. Solo puede existir un voto por combinación de usuario y reclamo. Mientras siga activo, pueden quitarlo y volver a colocarlo, sin duplicar votos.
- Pueden tener hasta **tres comentarios existentes por usuario por reclamo**, incluido uno propio, únicamente en `pendiente` o `en_proceso`. Pueden editar o eliminar solamente sus propios comentarios mientras el reclamo siga en uno de esos estados y no tenga baja lógica. Editar no consume otro lugar; eliminar libera un lugar para un nuevo comentario.
- En `resuelto` o `rechazado` se conservan y pueden consultarse los comentarios y votos existentes, pero no se puede crear, editar o eliminar comentarios ni dar o quitar votos.

## Edición y eliminación de reclamos

Estas acciones requieren identidad aprobada.

- Pueden editar el título, la descripción, la foto y la ubicación de un reclamo propio únicamente mientras esté `pendiente`, sin asignación y sin baja lógica. La edición no permite cambiar el creador, el estado ni las asignaciones.
- Pueden eliminar únicamente un reclamo propio que siga `pendiente`, nunca haya cambiado de estado y no esté asignado a un empleado ni a una cuadrilla. El registro inicial del historial no cuenta como cambio de estado.
- La eliminación es una baja lógica mediante `deleted_at`. El reclamo deja de aparecer en el mapa y en las consultas ciudadanas, no admite edición del reclamo ni cambios en votos o comentarios y no cuenta para el límite de activos. Se conservan sus datos, historial, votos y comentarios para la gestión administrativa.

## Empleados

- Pueden trabajar solos o pertenecer a una sola cuadrilla.
- Pueden consultar todos los reclamos visibles y sus asignaciones desde la vista de trabajo.
- Solo pueden modificar el estado de reclamos asignados directamente a ellos o a su cuadrilla actual. No pueden asignarse ni reasignar reclamos.
- Los cambios de estado autorizados, sus condiciones y observaciones se definen en [Transiciones](estados-reclamos.md#transiciones).
- Cuando usan las funciones ciudadanas, se aplican las mismas reglas y límites según su verificación de identidad. La verificación ciudadana no es un requisito para trabajar como empleado.

## Administradores

- Usan una cuenta exclusiva e independiente, con su propio email y contraseña, sin vínculo con una cuenta personal. El rol admin no otorga automáticamente funciones ciudadanas ni de empleado. No requiere verificación ciudadana: puede conservar los campos de identidad opcionales vacíos y `estado_verificacion = no_solicitada`.
- Pueden consultar todos los reclamos, incluidos los dados de baja, sus asignaciones e historial.
- Gestionan categorías, cuadrillas y cuentas de empleados, y asignan o reasignan reclamos a un empleado, a una cuadrilla o a ambos. Si se asignan ambos, el empleado debe pertenecer a esa cuadrilla. Los responsables deben tener rol empleado y estar activos; la cuadrilla asignada debe estar activa.
- La relación entre asignación y estado se define en [Asignación y baja lógica](estados-reclamos.md#asignación-y-baja-lógica).
- No se permite cambiar de cuadrilla a un empleado ni desactivar un empleado o cuadrilla si eso afecta reclamos activos asignados. El admin primero debe finalizar o reasignar esos reclamos. No se implementa un flujo de cambios de equipo durante trabajos en curso ni un historial de pertenencia a cuadrillas.
- Pueden gestionar cambios de estado según [Transiciones](estados-reclamos.md#transiciones). No hay edición libre del catálogo de estados.
- Pueden consultar el resultado de las solicitudes de verificación. En esta versión, la simulación del backend decide aleatoriamente la aprobación o rechazo; no hay revisión manual administrativa.
- Pueden desactivar y reactivar cuentas, excepto desactivar su propia cuenta o dejar al sistema sin un administrador activo. No eliminan usuarios referenciados ni modifican o borran el historial.

## Reglas comunes

- El backend comprueba en cada petición que la cuenta esté activa, sus permisos, la verificación cuando corresponda y la asignación necesaria. Una cuenta desactivada no puede usar las funciones autenticadas.
- El registro público y la edición del perfil no permiten concederse roles, aprobar la propia identidad ni modificar asignaciones.
- El registro de cambios y las posibles acciones del sistema siguen [Historial y observaciones](estados-reclamos.md#historial-y-observaciones).
- Desactivar usuarios, categorías o cuadrillas conserva sus registros y relaciones históricas. Las categorías desactivadas no se ofrecen para crear reclamos nuevos.

## Verificación de identidad

Para el MVP se guarda una sola solicitud vigente por cuenta, sin historial de intentos. Estos campos permiten una simulación propia o una integración con un proveedor en sandbox. Una aprobación de prueba demuestra el flujo; no acredita una identidad real.

La cuenta ciudadana puede registrarse y consultar el mapa y los reclamos sin verificar su identidad. Para crear reclamos, comentar o votar, debe tener `estado_verificacion = aprobada`. Esta condición también se aplica al empleado cuando utiliza funciones ciudadanas; sus permisos de trabajo se controlan por separado mediante el rol y la asignación del reclamo.

El flujo es `no_solicitada → pendiente → aprobada/rechazada`. Si se rechaza, puede volver a solicitarse y pasar a `pendiente`. Al iniciar una nueva solicitud se limpia `identidad_verificada_en` y se actualizan el método y la referencia correspondientes. No se inicia otra solicitud mientras haya una pendiente ni después de una aprobación. El usuario no puede aprobarse modificando su perfil.

Para esta primera versión se usa `metodo_verificacion = simulacion`: el backend genera y guarda un resultado aleatorio por solicitud, con 50 % de probabilidad de aprobación y 50 % de rechazo. Consultar el resultado no vuelve a sortearlo. Al aprobar se completa `identidad_verificada_en`; al rechazar permanece en `null`. Se usan datos ficticios para la demostración y no se comprueba una identidad real. La integración con un proveedor en sandbox queda como posibilidad futura; su resultado se recibiría mediante una notificación validada.

Después de aprobar la identidad no se permite editar `dni`, `nombre` ni `apellido`. Email y teléfono pueden cambiarse sin afectar esa aprobación; si se incorpora verificación de correo, cambiar el email exige verificar el nuevo y limpiar `email_verified_at`. No se implementa un proceso de cambio de identidad verificada en este MVP.

`email_verified_at` representa la verificación del correo, independiente de la verificación de identidad. Guardar un DNI tampoco equivale a verificarlo. Por ahora `dni` no tiene restricción de unicidad ni vincula cuentas.

## Reclamos potencialmente duplicados: mejora futura

Queda pendiente investigar un criterio para detectar reclamos que describen el mismo problema. Una primera aproximación puede comparar reclamos activos por tipo y cercanía geográfica; la descripción y las fotos podrían aportar criterios adicionales. Todavía no se define distancia, algoritmo ni implementación. Esta versión no bloquea ni identifica automáticamente duplicados.
