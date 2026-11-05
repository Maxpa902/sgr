import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../mapa/estilos.dart';
import '../../tema/colores.dart';
import 'estado_reclamo_badge.dart';

/// Un reclamo presentado de forma consistente en listados de los distintos roles.
///
/// [complemento] es información visual de solo lectura, por ejemplo un conteo.
/// Si se necesita una acción independiente, debe ubicarse fuera de esta fila.
class FilaReclamo extends StatelessWidget {
  const FilaReclamo({
    super.key,
    required this.titulo,
    required this.estado,
    required this.alAbrir,
    this.iconoCategoria,
    this.metadatos = const [],
    this.complemento,
    this.etiquetaAccesibleComplemento,
  });

  final String titulo;
  final String estado;
  final VoidCallback alAbrir;
  final IconData? iconoCategoria;
  final List<String> metadatos;
  final Widget? complemento;
  final String? etiquetaAccesibleComplemento;

  @override
  Widget build(BuildContext context) {
    final metadata = metadatos
        .where((valor) => valor.trim().isNotEmpty)
        .toList();
    final label = <String>[
      titulo,
      nombreDelEstado(estado),
      ...metadata,
      ...[etiquetaAccesibleComplemento].whereType<String>(),
    ].join(', ');

    return FTile(
      semanticsLabel: label,
      title: Text(titulo, maxLines: 2),
      subtitle: metadata.isEmpty ? null : Text(metadata.join(' · ')),
      prefix: iconoCategoria == null
          ? null
          : Icon(iconoCategoria, color: ColoresApp.secundario),
      details: EstadoReclamoBadge(estado: estado),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (complemento case final widget?) ...[
            ExcludeSemantics(child: widget),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onPress: alAbrir,
    );
  }
}
