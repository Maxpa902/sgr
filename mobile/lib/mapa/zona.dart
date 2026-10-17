import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// La zona que cubre el mapa: Comodoro Rivadavia (con Caleta Córdova) y
/// Rada Tilly. El mapa no deja moverse fuera de estos límites.
abstract final class ZonaDelMapa {
  static const nombre = 'Comodoro Rivadavia, Rada Tilly y Caleta Córdova';

  /// De Rada Tilly (al sur) a Caleta Córdova (al norte), y de Diadema
  /// Argentina (al oeste) al mar.
  static final limites = LatLngBounds(
    const LatLng(-45.97, -67.72),
    const LatLng(-45.71, -67.33),
  );

  /// Al abrir el mapa se ve el centro y la mayoría de los barrios de Comodoro.
  static const centroInicial = LatLng(-45.850, -67.495);
  static const zoomInicial = 12.5;

  static const zoomMinimo = 10.5;
  static const zoomMaximo = 18.0;

  /// Zoom al ir a "Mi ubicación": se ven las cuadras de alrededor.
  static const zoomCercano = 16.0;
}
