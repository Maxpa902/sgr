import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Un destino de navegación raíz para [BarraNavegacionPrincipal].
class DestinoNavegacion {
  const DestinoNavegacion({
    required this.id,
    required this.etiqueta,
    required this.icono,
    this.descripcionAccesible,
  });

  final String id;
  final String etiqueta;
  final IconData icono;
  final String? descripcionAccesible;
}

/// Navegación inferior Forui. El contenedor padre mantiene la selección.
class BarraNavegacionPrincipal extends StatelessWidget {
  const BarraNavegacionPrincipal({
    super.key,
    required this.destinos,
    required this.destinoActual,
    required this.alSeleccionar,
  }) : assert(destinos.length >= 2 && destinos.length <= 5);

  final List<DestinoNavegacion> destinos;
  final String destinoActual;
  final ValueChanged<String> alSeleccionar;

  @override
  Widget build(BuildContext context) {
    final index = destinos.indexWhere((destino) => destino.id == destinoActual);
    assert(index >= 0, 'destinoActual debe pertenecer a destinos.');
    assert(
      destinos.map((destino) => destino.id).toSet().length == destinos.length,
      'Los ids de los destinos deben ser únicos.',
    );

    return FBottomNavigationBar(
      style: .delta(decoration: .boxDelta(color: context.theme.colors.card)),
      index: index,
      onChange: (index) => alSeleccionar(destinos[index].id),
      children: [
        for (final destino in destinos)
          FBottomNavigationBarItem(
            key: ValueKey(destino.id),
            icon: Icon(destino.icono),
            label: Text(destino.etiqueta),
            semanticsLabel: destino.descripcionAccesible,
          ),
      ],
    );
  }
}
