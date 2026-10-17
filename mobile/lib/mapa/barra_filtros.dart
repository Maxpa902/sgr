import 'package:flutter/material.dart';

import '../modelos/tipo_reclamo.dart';
import 'estilos.dart';

/// Botones arriba del mapa para elegir qué reclamos ver. Los de estado también
/// sirven de referencia de colores.
class BarraFiltros extends StatelessWidget {
  const BarraFiltros({
    super.key,
    required this.estados,
    required this.tipos,
    required this.tiposElegidos,
    required this.alCambiarEstado,
    required this.alCambiarTipo,
  });

  /// Estados elegidos.
  final Set<String> estados;

  /// Todas las categorías disponibles.
  final List<TipoReclamo> tipos;

  /// Categorías elegidas, o `null` si se ven todas.
  final Set<int>? tiposElegidos;

  final ValueChanged<String> alCambiarEstado;
  final ValueChanged<int> alCambiarTipo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          for (final estado in estadosDelMapa)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                avatar: CircleAvatar(
                  backgroundColor: colorDelEstado(estado),
                  radius: 7,
                ),
                label: Text(nombreDelFiltro(estado)),
                selected: estados.contains(estado),
                showCheckmark: false,
                onSelected: (_) => alCambiarEstado(estado),
              ),
            ),
          if (tipos.isNotEmpty) const VerticalDivider(width: 16),
          for (final tipo in tipos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                avatar: Icon(iconoDeCategoria(tipo.icono), size: 18),
                label: Text(tipo.nombre),
                selected: tiposElegidos?.contains(tipo.id) ?? true,
                showCheckmark: false,
                onSelected: (_) => alCambiarTipo(tipo.id),
              ),
            ),
        ],
      ),
    );
  }
}
