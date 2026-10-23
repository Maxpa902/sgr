# Guía breve de UI/UX móvil

Aplicar estas pautas al diseñar o modificar la app Flutter. Priorizar tareas claras, accesibilidad, consistencia y recuperación ante errores. Respetar el sistema de diseño existente; no agregar bibliotecas sin una necesidad concreta.

## Pantallas y navegación

- Definir usuario, contexto y tarea principal antes de diseñar.
- Destacar la acción principal y mantener jerarquía visual clara.
- Usar componentes reutilizables y un tema centralizado para colores semánticos, tipografía, espaciado y bordes.
- Mantener navegación estable, sección activa visible y comportamiento de Atrás coherente. Separar destinos de acciones.
- Preservar filtros, desplazamiento y datos al volver o interrumpir la app.
- Usar textos breves, botones específicos e iconos con etiquetas cuando sean ambiguos.

## Accesibilidad y adaptación

- En Android, buscar áreas táctiles de al menos 48 × 48 unidades lógicas; en iOS, 44 × 44 pt. Separar controles y ofrecer alternativas a gestos ocultos.
- Contraste: al menos 4,5:1 para texto normal; 3:1 para texto grande según WCAG y elementos gráficos necesarios para reconocer controles y estados, con las excepciones del estándar.
- No depender solo del color o sonido. Admitir texto ampliado, reducción de movimiento y lectores de pantalla mediante semántica y foco lógico.
- Adaptar a pantallas pequeñas, áreas seguras, teclado, orientación e idiomas. Verificar modos claro y oscuro.

## Formularios y estados

- Pedir solo datos necesarios; usar etiquetas persistentes, teclado adecuado, autocompletado y pegado.
- Explicar errores junto al campo y conservar lo ingresado.
- Diseñar estados de carga, vacío, sin resultados, error con reintento, éxito, desconexión, sesión vencida y permiso denegado.
- Dar respuesta inmediata a las acciones; evitar envíos duplicados y bloqueos innecesarios.
- Confirmar acciones irreversibles según su riesgo y ofrecer Deshacer cuando sea viable.
- Distinguir datos locales, pendientes de sincronización y confirmados por el servidor.

## Confianza y validación

- Solicitar permisos mínimos al usar la función, explicar su motivo y contemplar el rechazo.
- Mantener onboarding breve y contextual; notificaciones útiles y configurables; evitar opciones engañosas.
- Optimizar imágenes, listas, batería y datos. Probar con red lenta y dispositivos modestos.
- Validar tareas con usuarios y dispositivos reales, incluyendo TalkBack/VoiceOver y texto ampliado. Medir éxito, errores, abandono y tiempos.

Referencia: WCAG 2.2 orienta accesibilidad; para apps nativas, complementarla con las guías de Android y Apple. Un componente existente no garantiza accesibilidad ni usabilidad por sí solo.
