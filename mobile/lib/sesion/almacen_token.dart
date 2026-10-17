import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dónde se guarda el token entre una apertura de la app y la siguiente.
///
/// Es una clase abstracta para que los tests puedan usar una versión en
/// memoria, sin depender del almacenamiento real del celular.
abstract class AlmacenToken {
  Future<String?> leer();

  Future<void> guardar(String token);

  Future<void> borrar();
}

/// Guarda el token cifrado en el almacenamiento seguro del celular.
class AlmacenTokenSeguro implements AlmacenToken {
  AlmacenTokenSeguro([FlutterSecureStorage? almacenamiento])
    : _almacenamiento = almacenamiento ?? const FlutterSecureStorage();

  static const _clave = 'token';

  final FlutterSecureStorage _almacenamiento;

  @override
  Future<String?> leer() => _almacenamiento.read(key: _clave);

  @override
  Future<void> guardar(String token) {
    return _almacenamiento.write(key: _clave, value: token);
  }

  @override
  Future<void> borrar() => _almacenamiento.delete(key: _clave);
}
