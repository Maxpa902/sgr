import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'paleta_mensajes.dart';

/// Tipo semántico de un mensaje transitorio.
enum TipoNotificacion { informacion, exito, advertencia, error }

/// Configuración de una acción opcional en una notificación.
class AccionNotificacion {
  const AccionNotificacion({required this.etiqueta, required this.alActivar});

  final String etiqueta;
  final VoidCallback alActivar;
}

/// Acceso común a los toasts Forui de la app.
///
/// El contexto de [mostrar] debe estar bajo un `FToaster`. Su instalación en
/// el host de la aplicación se decide al integrar las pantallas.
abstract final class Notificaciones {
  static final Map<Object, FToasterEntry> _notificacionesConId = {};

  static PaletaMensaje _paleta(TipoNotificacion tipo) => switch (tipo) {
    TipoNotificacion.informacion => PaletaMensaje.informacion,
    TipoNotificacion.exito => PaletaMensaje.exito,
    TipoNotificacion.advertencia => PaletaMensaje.advertencia,
    TipoNotificacion.error => PaletaMensaje.error,
  };

  static FToasterEntry mostrar(
    BuildContext context, {
    required TipoNotificacion tipo,
    required String mensaje,
    AccionNotificacion? accion,
    Object? id,
  }) {
    final paleta = _paleta(tipo);
    final style = context.theme.style;

    if (id case final key?) {
      _notificacionesConId.remove(key)?.dismiss();
    }

    late final FToasterEntry entry;
    entry = showFToast(
      context: context,
      variant: tipo == TipoNotificacion.error ? .destructive : .primary,
      style: FToastStyleDelta.delta(
        decoration: DecorationDelta.shapeDelta(
          color: paleta.fondo,
          shape: RoundedSuperellipseBorder(
            side: BorderSide(color: paleta.borde, width: style.borderWidth),
            borderRadius: style.borderRadius.md,
          ),
        ),
        iconStyle: IconThemeDataDelta.delta(color: paleta.primerPlano),
        titleTextStyle: TextStyleDelta.delta(color: paleta.primerPlano),
        descriptionTextStyle: TextStyleDelta.delta(color: paleta.primerPlano),
      ),
      title: Text(mensaje),
      icon: Icon(_icono(tipo)),
      alignment: FToastAlignment.bottomCenter,
      duration: accion == null ? const Duration(seconds: 5) : null,
      suffixBuilder: accion == null
          ? null
          : (_, toastEntry) => FButton(
              variant: .ghost,
              size: .sm,
              onPress: () {
                accion.alActivar();
                toastEntry.dismiss();
              },
              child: Text(
                accion.etiqueta,
                style: TextStyle(color: paleta.primerPlano),
              ),
            ),
      onDismiss: () {
        if (id case final key?
            when identical(_notificacionesConId[key], entry)) {
          _notificacionesConId.remove(key);
        }
      },
    );

    if (id case final key?) _notificacionesConId[key] = entry;
    return entry;
  }

  static IconData _icono(TipoNotificacion tipo) => switch (tipo) {
    TipoNotificacion.informacion => Icons.info_outline,
    TipoNotificacion.exito => Icons.check_circle_outline,
    TipoNotificacion.advertencia => Icons.warning_amber_outlined,
    TipoNotificacion.error => Icons.error_outline,
  };
}
