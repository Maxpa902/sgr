import 'package:flutter/material.dart';

class BannerSanciones extends StatelessWidget {
  const BannerSanciones({
    super.key,
    required this.estaSuspendido,
    this.alcanzoLimiteReclamos = false,
  });

  /// Indica si la cuenta está suspendida: cada reclamo falso suspende 30 días.
  final bool estaSuspendido;

  /// Indica si ya tiene 3 reclamos activos (pendientes o en proceso)
  final bool alcanzoLimiteReclamos;

  @override
  Widget build(BuildContext context) {
    // 1. Si está suspendido por un reclamo falso
    if (estaSuspendido) {
      return _construirCard(
        colorFondo: Colors.red.shade50,
        colorBorde: Colors.red.shade400,
        colorIconoTexto: Colors.red.shade900,
        icono: Icons.block,
        texto:
            'Tu cuenta está suspendida temporalmente para crear reclamos debido a reportes falsos. Podrás volver a publicar más adelante.',
      );
    }

    // 2. Si alcanzó el límite de 3 reclamos activos
    if (alcanzoLimiteReclamos) {
      return _construirCard(
        colorFondo: Colors.amber.shade50,
        colorBorde: Colors.amber.shade400,
        colorIconoTexto: Colors.amber.shade900,
        icono: Icons.warning_amber_rounded,
        texto:
            'Alcanzaste el límite de 3 reclamos activos. Esperá a que se resuelvan para crear uno nuevo.',
      );
    }

    // 3. Si no tiene nada, no muestra nada
    return const SizedBox.shrink();
  }

  Widget _construirCard({
    required Color colorFondo,
    required Color colorBorde,
    required Color colorIconoTexto,
    required IconData icono,
    required String texto,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        color: colorFondo,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorBorde),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icono,
                color: colorIconoTexto,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    color: colorIconoTexto,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
