import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../modelos/usuario.dart';
import 'almacen_token.dart';

/// En qué situación está la sesión. La app elige qué pantalla mostrar según esto.
enum EstadoSesion {
  /// Se está revisando si hay una sesión guardada.
  cargando,

  /// Hay una sesión guardada, pero el server no respondió para confirmarla.
  sinConexion,

  /// Nadie inició sesión.
  sinSesion,

  /// Hay un usuario con la sesión iniciada.
  conSesion,
}

/// Recuerda quién está logueado y avisa a las pantallas cuando eso cambia.
///
/// Es un [ChangeNotifier]: cada vez que llama a [notifyListeners], los widgets
/// que la escuchan se vuelven a dibujar.
class Sesion extends ChangeNotifier {
  Sesion({required this._api, required this._almacen});

  final ApiClient _api;
  final AlmacenToken _almacen;

  EstadoSesion _estado = EstadoSesion.cargando;
  Usuario? _usuario;

  EstadoSesion get estado => _estado;

  /// El cliente que tiene el token de esta sesión. Las pantallas lo usan para
  /// pedirle datos al server en nombre del usuario logueado.
  ApiClient get api => _api;

  /// El usuario logueado, o `null` si no hay sesión.
  Usuario? get usuario => _usuario;

  /// Al abrir la app: si hay un token guardado, le pregunta al server si
  /// todavía sirve.
  Future<void> restaurar() async {
    _cambiarEstado(EstadoSesion.cargando);

    final token = await _almacen.leer();
    if (token == null) {
      _cambiarEstado(EstadoSesion.sinSesion);
      return;
    }

    _api.token = token;
    try {
      _usuario = await _api.usuarioActual();
      _cambiarEstado(EstadoSesion.conSesion);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        // El token ya no sirve: se cerró la sesión o se desactivó la cuenta.
        await _olvidarSesion();
      } else {
        // El server no respondió: se conserva el token para reintentar.
        _cambiarEstado(EstadoSesion.sinConexion);
      }
    }
  }

  /// Lanza [ApiException] si el server rechaza los datos.
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final sesion = await _api.iniciarSesion(email: email, password: password);
    await _guardar(sesion);
  }

  /// Lanza [ApiException] si el server rechaza los datos.
  Future<void> registrarse({
    required String nombre,
    required String apellido,
    required String dni,
    required String email,
    required String password,
    required String passwordConfirmacion,
    String? telefono,
  }) async {
    final sesion = await _api.registrarse(
      nombre: nombre,
      apellido: apellido,
      dni: dni,
      email: email,
      password: password,
      passwordConfirmacion: passwordConfirmacion,
      telefono: telefono,
    );
    await _guardar(sesion);
  }

  /// Cierra la sesión en el server y en el celular. Si el server no responde,
  /// igual la cierra en el celular.
  Future<void> cerrarSesion() async {
    try {
      await _api.cerrarSesion();
    } on ApiException {
      // Sin conexión o token vencido: alcanza con olvidarlo en el celular.
    }
    await _olvidarSesion();
  }

  Future<void> _guardar(SesionIniciada sesion) async {
    await _almacen.guardar(sesion.token);
    _api.token = sesion.token;
    _usuario = sesion.usuario;
    _cambiarEstado(EstadoSesion.conSesion);
  }

  Future<void> _olvidarSesion() async {
    await _almacen.borrar();
    _api.token = null;
    _usuario = null;
    _cambiarEstado(EstadoSesion.sinSesion);
  }

  void _cambiarEstado(EstadoSesion estado) {
    _estado = estado;
    notifyListeners();
  }
}
