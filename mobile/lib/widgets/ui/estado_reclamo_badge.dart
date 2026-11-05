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
  Widget build(BuildContext context) => FBadge(
    variant: .outline,
    child: Text(
      nombreDelEstado(estado),
      style: TextStyle(color: ColoresApp.estadoReclamo(estado)),
    ),
  );
}
