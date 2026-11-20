import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../mapa/estilos.dart';
import '../../tema/colores.dart';

/// Representación común del estado de un reclamo.
///
/// La etiqueta y el color se resuelven aquí para no repetirlos en cada lista.
class EstadoReclamoBadge extends StatelessWidget {
  const EstadoReclamoBadge({super.key, required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final colorEstado = ColoresApp.estadoReclamo(estado);
    // Tonos oscuros para que el texto siga siendo legible sobre el fondo suave.
    final colorTexto = switch (estado) {
      'pendiente' => const Color(0xFF833907),
      'en_proceso' => const Color(0xFF1E40AF),
      'resuelto' => const Color(0xFF166534),
      'rechazado' => const Color(0xFF991B1B),
      _ => const Color(0xFF424D4A),
    };

    return FBadge(
      variant: .outline,
      style: .delta(
        decoration: .shapeDelta(
          color: Color.alphaBlend(
            colorEstado.withValues(alpha: 0.10),
            Colors.white,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.circle, size: 7, color: colorTexto),
          ),
          const SizedBox(width: 6),
          Text(
            nombreDelEstado(estado),
            style: TextStyle(color: colorTexto, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
