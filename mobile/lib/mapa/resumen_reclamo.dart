import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../formato.dart';
import '../modelos/reclamo_mapa.dart';
import '../widgets/componentes_ui.dart';

/// Vista breve para reconocer un reclamo antes de abrir su detalle.
class ResumenReclamo {
  const ResumenReclamo({required this.reclamo});

  final ReclamoMapa reclamo;

  Future<bool?> mostrar(BuildContext context) {
    final direccion = reclamo.direccion?.trim();
    final descripcion = reclamo.descripcion?.trim();
    return PanelInferior(
      titulo: reclamo.titulo,
      maxLineasTitulo: 2,
      proporcionAlturaMaxima: 0.6,
      contenido: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              [
                reclamo.tipo.nombre,
                if (direccion != null && direccion.isNotEmpty) direccion,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.body.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EstadoReclamoBadge(estado: reclamo.estado),
                Text(
                  'Cargado ${haceCuanto(reclamo.creadoEn)}',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
            if (descripcion != null && descripcion.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(descripcion, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _Conteo(
                  icono: Icons.thumb_up_outlined,
                  texto: '${reclamo.confirmaciones} confirmaciones',
                ),
                _Conteo(
                  icono: Icons.thumb_down_outlined,
                  texto: '${reclamo.desmentidas} desmentidas',
                ),
              ],
            ),
          ],
        ),
      ),
      acciones: [
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(context).pop(true),
            child: const Text('Ver reclamo completo'),
          ),
        ),
      ],
    ).mostrar<bool>(context);
  }
}

class _Conteo extends StatelessWidget {
  const _Conteo({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 18, color: context.theme.colors.mutedForeground),
      const SizedBox(width: 6),
      Text(
        texto,
        style: context.theme.typography.body.sm.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
    ],
  );
}
