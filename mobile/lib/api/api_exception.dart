/// Error al hablar con el server, con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.mensaje, {this.statusCode, this.errores = const {}});

  /// El server no respondió: está apagado, no hay internet o tardó demasiado.
  const ApiException.sinConexion()
    : mensaje =
          'No se pudo conectar con el servidor. Revisá tu conexión e intentá de nuevo.',
      statusCode = null,
      errores = const {};

  final String mensaje;

  /// Código HTTP de la respuesta, o `null` si el server no respondió.
  final int? statusCode;

  /// Primer error de cada campo, cuando el server rechaza los datos (422).
  /// Por ejemplo: `{'dni': 'Ya existe una cuenta con ese DNI.'}`.
  final Map<String, String> errores;

  bool get sinConexion => statusCode == null;

  @override
  String toString() => 'ApiException($statusCode): $mensaje';
}
