import '../modelos/reclamo_mapa.dart';

/// Error al hablar con el server, con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  const ApiException(
    this.mensaje, {
    this.statusCode,
    this.errores = const {},
    this.todosLosErrores = const {},
    this.reclamoDuplicado,
  });

  /// El server no respondió: está apagado, no hay internet o tardó demasiado.
  const ApiException.sinConexion()
    : mensaje =
          'No se pudo conectar con el servidor. Revisá tu conexión e intentá de nuevo.',
      statusCode = null,
      errores = const {},
      todosLosErrores = const {},
      reclamoDuplicado = null;

  final String mensaje;

  /// Código HTTP de la respuesta, o `null` si el server no respondió.
  final int? statusCode;

  /// Primer error de cada campo, cuando el server rechaza los datos (422).
  final Map<String, String> errores;

  /// Todos los mensajes de validación agrupados por campo.
  final Map<String, List<String>> todosLosErrores;

  /// Reclamo existente retornado en caso de conflicto por duplicación (409).
  final ReclamoMapa? reclamoDuplicado;

  bool get sinConexion => statusCode == null;

  @override
  String toString() => 'ApiException($statusCode): $mensaje';
}
