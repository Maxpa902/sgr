# Componentes comunes de UI

Catálogo breve de los componentes compartidos de la app móvil. Complementa [UI_UX.md](UI_UX.md), que contiene las pautas generales de accesibilidad y diseño.

## Dónde están

- Implementación: `lib/widgets/ui/`.
- Exportación: `lib/widgets/componentes_ui.dart`.
- Tema usado por Operario: `lib/tema/`.
- Galería de ejemplo: sección **Prueba** de Operario.

Los componentes están implementados. Operario ya usa varios; la mayoría de las pantallas de vecino y administración todavía no se migraron. La galería sirve para revisar variantes, pero no reemplaza la validación en la app.

## Catálogo

| Componente | Uso |
| --- | --- |
| `LayoutPagina` | Encabezado, contenido y pie de una página. |
| `BarraNavegacionPrincipal` | Navegación entre destinos principales. |
| `EstadoReclamoBadge` | Etiqueta y color de un estado de reclamo. |
| `FilaReclamo` | Presentación de un reclamo en una lista. |
| `EstadoContenido` | Estado vacío, sin resultados o error con recuperación opcional. |
| `AvisoEnLinea` | Mensaje informativo o de error junto al contenido. |
| `Dialogo` y `confirmarAccion` | Diálogos y confirmaciones. |
| `PanelInferior` | Panel modal que aparece desde abajo. |
| `Notificaciones` | Mensajes breves con toast Forui. |

## Reglas de uso

- Las pantallas conservan la carga de datos, los permisos y las decisiones del flujo. Los componentes reciben datos y callbacks.
- Usar Forui directamente cuando el componente compartido no aporte una estructura o comportamiento reutilizable.
- No agregar variantes por rol ni crear wrappers que solo cambien el nombre de un componente Forui.
- Mantener las acciones particulares de cada flujo fuera de los componentes visuales.
- Los mapas pueden ocupar el cuerpo a borde completo. Sus controles y leyendas deben permanecer visibles y no taparse entre sí.

## Pendiente

- Extender la adopción a vecino y administración donde corresponda.
- Unificar tema y estilos entre roles cuando se migren sus pantallas.
- Validar accesibilidad y adaptación en la app ejecutándose; los componentes por sí solos no garantizan ninguna de las dos.
