import 'package:flutter/painting.dart';

/// Paleta para el tema claro de la aplicación.
///
/// Como las variables de un archivo CSS, cada nombre representa una función.
/// Por ejemplo, un botón principal podrá usar [principal] para su fondo y
/// [sobrePrincipal] para su texto. Se utiliza en el flujo de operario y en
/// los componentes comunes migrados.
abstract final class ColoresApp {
  // Identidad y acciones.
  static const principal = Color(0xFF185A80);
  static const principalPresionado = Color(0xFF124562);
  static const principalSuave = Color(0xFFE8F2F8);
  static const sobrePrincipal = Color(0xFFFFFFFF);

  static const secundario = Color(0xFF176B5B);
  static const secundarioPresionado = Color(0xFF115548);
  static const secundarioSuave = Color(0xFFE7F2EF);
  static const sobreSecundario = Color(0xFFFFFFFF);

  // Superficies y contenido general.
  static const fondo = Color(0xFFF7F9F8);
  static const superficie = Color(0xFFFFFFFF);
  static const textoPrincipal = Color(0xFF1C2927);
  static const textoBotonSecundario = Color(0xFF000000);
  static const textoSecundario = Color(0xFF52615E);
  static const borde = Color(0xFFDCE5E1);
  static const separador = borde;

  // Mensajes: texto e icono, fondo y borde para cada tipo.
  static const informacion = Color(0xFF174D78);
  static const informacionFondo = Color(0xFFEAF4FB);
  static const informacionBorde = Color(0xFFA7CDEA);

  static const exito = Color(0xFF315C3D);
  static const exitoFondo = Color(0xFFEAF3EC);
  static const exitoBorde = Color(0xFFAFCBB4);

  static const advertencia = Color(0xFF664C00);
  static const advertenciaFondo = Color(0xFFFFF4CC);
  static const advertenciaBorde = Color(0xFFE7C96D);

  static const error = Color(0xFF8A2A25);
  static const errorFondo = Color(0xFFFCE9E7);
  static const errorBorde = Color(0xFFE6AAA5);

  // Estados de reclamo: se acompañan siempre de una etiqueta.
  static const reclamoPendiente = Color(0xFFB45309);
  static const reclamoEnProceso = Color(0xFF1D4ED8);
  static const reclamoResuelto = Color(0xFF15803D);
  static const reclamoRechazado = Color(0xFFB91C1C);
  static const reclamoDesconocido = Color(0xFF757575);

  /// Color de presentación para cada estado, también usado en el mapa.
  static Color estadoReclamo(String estado) => switch (estado) {
    'pendiente' => reclamoPendiente,
    'en_proceso' => reclamoEnProceso,
    'resuelto' => reclamoResuelto,
    'rechazado' => reclamoRechazado,
    _ => reclamoDesconocido,
  };
}
