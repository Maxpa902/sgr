import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'paleta_mensajes.dart';

/// Tipo semántico para un aviso que debe permanecer junto a su contenido.
enum TipoAviso { informacion, exito, advertencia, error }

/// Una acción breve asociada a un aviso.
class AccionAviso {
  const AccionAviso({required this.etiqueta, required this.alActivar});

  final String etiqueta;
  final VoidCallback alActivar;
}

/// Aviso en línea con icono y estilo semántico Forui.
class AvisoEnLinea extends StatelessWidget {
  const AvisoEnLinea({
    super.key,
    required this.tipo,
    required this.mensaje,
    this.titulo,
    this.accion,
  });

  final TipoAviso tipo;
  final String mensaje;
  final String? titulo;
  final AccionAviso? accion;

  String get _titulo =>
      titulo ??
      switch (tipo) {
        TipoAviso.informacion => 'Información',
        TipoAviso.exito => 'Listo',
        TipoAviso.advertencia => 'Atención',
        TipoAviso.error => 'No se pudo completar',
      };

  IconData get _icono => switch (tipo) {
    TipoAviso.informacion => Icons.info_outline,
    TipoAviso.exito => Icons.check_circle_outline,
    TipoAviso.advertencia => Icons.warning_amber_outlined,
    TipoAviso.error => Icons.error_outline,
  };

  PaletaMensaje get _paleta => switch (tipo) {
    TipoAviso.informacion => PaletaMensaje.informacion,
    TipoAviso.exito => PaletaMensaje.exito,
    TipoAviso.advertencia => PaletaMensaje.advertencia,
    TipoAviso.error => PaletaMensaje.error,
  };

  @override
  Widget build(BuildContext context) {
    final paleta = _paleta;
    final style = context.theme.style;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FAlert(
          variant: tipo == TipoAviso.error ? .destructive : .primary,
          style: FAlertStyleDelta.delta(
            decoration: DecorationDelta.shapeDelta(
              color: paleta.fondo,
              shape: RoundedSuperellipseBorder(
                side: BorderSide(color: paleta.borde, width: style.borderWidth),
                borderRadius: style.borderRadius.md,
              ),
            ),
            iconStyle: IconThemeDataDelta.delta(color: paleta.primerPlano),
            titleTextStyle: TextStyleDelta.delta(color: paleta.primerPlano),
            subtitleTextStyle: TextStyleDelta.delta(color: paleta.primerPlano),
          ),
          title: Text(_titulo),
          subtitle: Text(mensaje),
          icon: Icon(_icono),
        ),
        if (accion case final action?) ...[
          const SizedBox(height: 8),
          FButton(
            variant: .outline,
            onPress: action.alActivar,
            child: Text(action.etiqueta),
          ),
        ],
      ],
    );
  }
}
