import 'package:flutter/material.dart';

/// Recuadro rojo con un mensaje de error.
class MensajeError extends StatelessWidget {
  const MensajeError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Card(
      color: colores.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colores.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: TextStyle(color: colores.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
