import 'package:flutter/material.dart';

import '../modelos/reclamo_mapa.dart';
import 'estilos.dart';

/// El pin de un reclamo: el color dice el estado y el ícono, la categoría.
/// Cuantas más confirmaciones tiene, más grande se ve.
class PinReclamo extends StatelessWidget {
  const PinReclamo({super.key, required this.reclamo, required this.alTocar});

  final ReclamoMapa reclamo;
  final VoidCallback alTocar;

  /// Lugar que ocupa el pin en el mapa, contando el número de confirmaciones.
  static double espacio(ReclamoMapa reclamo) => _diametro(reclamo) + 12;

  static double _diametro(ReclamoMapa reclamo) {
    if (reclamo.confirmaciones >= 10) {
      return 52;
    }
    return reclamo.destacado ? 44 : 34;
  }

  @override
  Widget build(BuildContext context) {
    final diametro = _diametro(reclamo);
    final color = colorDelEstado(reclamo.estado);

    return Semantics(
      button: true,
      label:
          '${reclamo.titulo}, ${nombreDelEstado(reclamo.estado).toLowerCase()}',
      child: GestureDetector(
        onTap: alTocar,
        child: Center(
          child: SizedBox.square(
            dimension: diametro,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      iconoDeCategoria(reclamo.tipo.icono),
                      color: Colors.white,
                      size: diametro * 0.55,
                    ),
                  ),
                ),
                if (reclamo.confirmaciones > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: _Confirmaciones(
                      cantidad: reclamo.confirmaciones,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El numerito con las confirmaciones, arriba a la derecha del pin.
class _Confirmaciones extends StatelessWidget {
  const _Confirmaciones({required this.cantidad, required this.color});

  final int cantidad;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$cantidad',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Burbuja que reemplaza a varios pines muy juntos. Al tocarla, el mapa se
/// acerca y los separa.
class BurbujaDeReclamos extends StatelessWidget {
  const BurbujaDeReclamos({super.key, required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Semantics(
      label: '$cantidad reclamos juntos',
      child: Container(
        decoration: BoxDecoration(
          color: colores.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$cantidad',
            style: TextStyle(
              color: colores.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// El punto azul que marca dónde está el celular.
class PuntoMiUbicacion extends StatelessWidget {
  const PuntoMiUbicacion({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tu ubicación',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}
