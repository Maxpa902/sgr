import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Tipo de estado de contenido que una pantalla quiere explicar.
enum EstadoContenidoTipo { vacio, sinResultados, error }

/// Acción contextual simple para un estado vacío o con error.
class AccionContenido {
  const AccionContenido({required this.etiqueta, required this.alActivar});

  final String etiqueta;
  final VoidCallback alActivar;
}

/// Mensaje central reutilizable para estados vacíos, filtros sin coincidencias o errores.
class EstadoContenido extends StatelessWidget {
  const EstadoContenido({
    super.key,
    required this.tipo,
    required this.titulo,
    this.descripcion,
    this.accion,
    this.icono,
  });

  final EstadoContenidoTipo tipo;
  final String titulo;
  final String? descripcion;
  final AccionContenido? accion;
  final IconData? icono;

  IconData get _icono =>
      icono ??
      switch (tipo) {
        EstadoContenidoTipo.vacio => Icons.inbox_outlined,
        EstadoContenidoTipo.sinResultados => Icons.search_off_outlined,
        EstadoContenidoTipo.error => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icono, size: 48, color: context.theme.colors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: context.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (descripcion case final value?) ...[
              const SizedBox(height: 8),
              Text(
                value,
                textAlign: TextAlign.center,
                style: context.theme.typography.body.md.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
            if (accion case final action?) ...[
              const SizedBox(height: 20),
              FButton(onPress: action.alActivar, child: Text(action.etiqueta)),
            ],
          ],
        ),
      ),
    ),
  );
}
