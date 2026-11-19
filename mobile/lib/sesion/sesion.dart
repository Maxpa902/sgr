import 'dart:io';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../modelos/reclamo_mapa.dart';
import '../modelos/reclamo_admin.dart';
import '../modelos/reclamo_detalle_admin.dart';
import '../modelos/tipo_reclamo.dart';
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

  /// Consulta un bloque del directorio de cuentas (el server exige rol admin).
  Future<PaginaUsuarios> listarUsuarios({
    String? busqueda,
    String? rol,
    String? estado,
    String? cursor,
  }) => _api.listarUsuarios(
    busqueda: busqueda,
    rol: rol,
    estado: estado,
    cursor: cursor,
  );


/// Lista reclamos para el panel de admin a través de la sesión.
  Future<PaginaReclamosAdmin> listarReclamosAdmin({
    String? busqueda,
    String? estado,
    int? tipoId,
    bool urgentes = false,
    bool incluirBajas = false,
    String? cursor,
  }) {
    return _api.listarReclamosAdmin(
      busqueda: busqueda,
      estado: estado,
      tipoId: tipoId,
      urgentes: urgentes,
      incluirBajas: incluirBajas,
      cursor: cursor,
    );
  }

  Future<PaginaUsuarios> listarUsuariosAdmin({
    String? busqueda,
    String? rol,
    String? estado,
    String? cursor,
  }) => _api.listarUsuariosAdmin(
    busqueda: busqueda,
    rol: rol,
    estado: estado,
    cursor: cursor,
  );

  /// Refresca los datos del usuario logueado desde el server (sanciones, suspensión, etc.).
  Future<void> refrescarUsuario() async {
    _usuario = await _api.usuarioActual();
    notifyListeners();
  }

  Future<void> actualizarCuenta(int usuarioId, {bool? activo, String? rol}) =>
      _api.actualizarCuenta(usuarioId, activo: activo, rol: rol);

  Future<void> crearCategoria({required String nombre, String? descripcion, String? icono}) =>
      _api.crearCategoria(nombre: nombre, descripcion: descripcion, icono: icono);

  Future<void> actualizarCategoria(int id, {required String nombre, String? descripcion, String? icono, bool? activo}) =>
      _api.actualizarCategoria(id, nombre: nombre, descripcion: descripcion, icono: icono, activo: activo);

  Future<void> toggleActivoCategoria(int id, bool activo) =>
      _api.toggleActivoCategoria(id, activo);

  Future<ReclamoDetalleAdmin> obtenerReclamoAdmin(int id) =>
      _api.obtenerReclamoAdmin(id);

  Future<List<TipoReclamo>> tiposDeReclamoAdmin() => _api.tiposDeReclamoAdmin();

  int _versionReclamos = 0;
  int get versionReclamos => _versionReclamos;
  /// Obtiene la lista de reclamos creados por el usuario actual o en los que votó.
  Future<List<ReclamoMapa>> misReclamos() => _api.misReclamos();

  Future<ReclamoMapa> crearReclamo({
      required String titulo,
      required String descripcion,
      required int tipoId,
      required double latitud,
      required double longitud,
      File? imagen,
      bool forzarCreacion = false,
    }) async {
      final creado = await _api.crearReclamo(
        titulo: titulo,
        descripcion: descripcion,
        tipoId: tipoId,
        latitud: latitud,
        longitud: longitud,
        imagen: imagen,
        forzarCreacion: forzarCreacion,
      );
      _versionReclamos++;
      notifyListeners();
      return creado;
    }

    Future<ReclamoMapa> editarReclamo({
      required int id,
      required String titulo,
      required String descripcion,
      required double latitud,
      required double longitud,
      List<int> fotosEliminar = const [],
      List<File> nuevasImagenes = const [],
    }) async {
      final editado = await _api.editarReclamo(
        id: id,
        titulo: titulo,
        descripcion: descripcion,
        latitud: latitud,
        longitud: longitud,
        fotosEliminar: fotosEliminar,
        nuevasImagenes: nuevasImagenes,
      );
      _versionReclamos++;
      notifyListeners();
      return editado;
    }

    Future<void> eliminarReclamo(int id) async {
      await _api.eliminarReclamo(id);
      _versionReclamos++;
      notifyListeners();
    }
  /// Obtiene la lista de vecinos que votaron en un reclamo.
  Future<List<Map<String, dynamic>>> obtenerVotantes(int reclamoId) {
    return _api.obtenerVotantes(reclamoId);
  }

  /// Envía un voto (confirma/desmiente) para un reclamo.
  Future<Map<String, dynamic>> votarReclamo(int reclamoId, String valor) {
    return _api.votarReclamo(reclamoId, valor);
  }

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


  Future<List<Usuario>> obtenerUsuariosConSancionesOrdenados() async {
    return _api.listarUsuariosConSanciones();
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


  /// Actualiza el perfil del usuario actual en el server y refresca la sesión local.
  Future<void> actualizarPerfil({
    required String nombre,
    required String apellido,
    required String email,
    String? telefono,
    String? passwordActual,
    String? password,
    String? passwordConfirmacion,
  }) async {
    final actualizado = await _api.actualizarPerfil(
      nombre: nombre,
      apellido: apellido,
      email: email,
      telefono: telefono,
      passwordActual: passwordActual,
      password: password,
      passwordConfirmacion: passwordConfirmacion,
    );
    _usuario = actualizado;
    notifyListeners();
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
