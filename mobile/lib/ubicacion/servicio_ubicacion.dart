import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Error al buscar la ubicación, con un mensaje listo para mostrar.
class UbicacionException implements Exception {
  const UbicacionException(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'UbicacionException: $mensaje';
}

/// Averigua dónde está el celular.
///
/// Es una clase abstracta para que los tests puedan simular una ubicación sin
/// GPS real.
abstract class ServicioUbicacion {
  /// Lanza [UbicacionException] si no hay permiso o no se puede ubicar.
  Future<LatLng> ubicacionActual();
}

/// Usa el GPS del celular. La primera vez le pide permiso al usuario.
class UbicacionDelDispositivo implements ServicioUbicacion {
  const UbicacionDelDispositivo();

  @override
  Future<LatLng> ubicacionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const UbicacionException(
        'Activá la ubicación del celular para usar esta función.',
      );
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw const UbicacionException(
        'Sin permiso de ubicación no podemos mostrarte dónde estás.',
      );
    }
    if (permiso == LocationPermission.deniedForever) {
      throw const UbicacionException(
        'El permiso de ubicación está bloqueado. Habilitalo desde los ajustes del celular.',
      );
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(posicion.latitude, posicion.longitude);
    } on TimeoutException {
      throw const UbicacionException(
        'No pudimos encontrar tu ubicación. Probá de nuevo en un rato.',
      );
    }
  }
}
