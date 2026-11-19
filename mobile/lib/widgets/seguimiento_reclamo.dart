import 'package:flutter/material.dart';

import '../formato.dart';
import '../mapa/estilos.dart';
import '../modelos/cambio_de_estado.dart';
import '../sesion/sesion.dart';
import '../tema/colores.dart';

/// Línea de tiempo con los cambios de estado de un reclamo, para cualquier vecino.
///
/// Los cambios del personal se muestran como "Cooperativa": el server no manda
/// quién los hizo ni las observaciones internas.
class SeguimientoReclamo extends StatefulWidget {
  const SeguimientoReclamo({
    super.key,
    required this.sesion,
    required this.reclamoId,
  });

  final Sesion sesion;
  final int reclamoId;

  @override
  State<SeguimientoReclamo> createState() => _SeguimientoReclamoState();
}

class _SeguimientoReclamoState extends State<SeguimientoReclamo> {
  late Future<List<CambioDeEstado>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _pedirSeguimiento();
  }

  Future<List<CambioDeEstado>> _pedirSeguimiento() =>
      widget.sesion.api.seguimientoDeReclamo(widget.reclamoId);

  void _reintentar() {
    setState(() {
      _futuro = _pedirSeguimiento();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seguimiento', style: textos.titleMedium),
        const SizedBox(height: 12),
        FutureBuilder<List<CambioDeEstado>>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (snapshot.hasError) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'No se pudo cargar el seguimiento.',
                      style: textos.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _reintentar,
                    child: const Text('Reintentar'),
                  ),
                ],
              );
            }

            final cambios = snapshot.data ?? const [];
            if (cambios.isEmpty) {
              return Text(
                'Todavía no hay cambios registrados.',
                style: textos.bodyMedium,
              );
            }
            return Column(
              children: [
                for (final (indice, cambio) in cambios.indexed)
                  _FilaCambio(
                    cambio: cambio,
                    esElUltimo: indice == cambios.length - 1,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Un punto de la línea de tiempo: estado y fecha, quién y la observación pública.
class _FilaCambio extends StatelessWidget {
  const _FilaCambio({required this.cambio, required this.esElUltimo});

  final CambioDeEstado cambio;
  final bool esElUltimo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    // El estado inicial lo genera el vecino al cargar el reclamo; el resto, el personal.
    final quien = cambio.estado == 'pendiente'
        ? 'Reclamo cargado'
        : 'Cooperativa';
    final observacion = cambio.observacion?.trim() ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colorDelEstado(cambio.estado),
                  shape: BoxShape.circle,
                ),
              ),
              if (!esElUltimo)
                Expanded(child: Container(width: 2, color: ColoresApp.borde)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esElUltimo ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${nombreDelEstado(cambio.estado)} · '
                    '${fechaCorta(cambio.creadoEn)}',
                    style: textos.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    observacion.isEmpty ? quien : '$quien: $observacion',
                    style: textos.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
