import 'package:flutter/material.dart';

import '../../tema/colores.dart';

/// Colores compartidos para los mensajes semánticos de la aplicación.
@immutable
class PaletaMensaje {
  const PaletaMensaje({
    required this.primerPlano,
    required this.fondo,
    required this.borde,
  });

  final Color primerPlano;
  final Color fondo;
  final Color borde;

  static const informacion = PaletaMensaje(
    primerPlano: ColoresApp.informacion,
    fondo: ColoresApp.informacionFondo,
    borde: ColoresApp.informacionBorde,
  );

  static const exito = PaletaMensaje(
    primerPlano: ColoresApp.exito,
    fondo: ColoresApp.exitoFondo,
    borde: ColoresApp.exitoBorde,
  );

  static const advertencia = PaletaMensaje(
    primerPlano: ColoresApp.advertencia,
    fondo: ColoresApp.advertenciaFondo,
    borde: ColoresApp.advertenciaBorde,
  );

  static const error = PaletaMensaje(
    primerPlano: ColoresApp.error,
    fondo: ColoresApp.errorFondo,
    borde: ColoresApp.errorBorde,
  );
}
