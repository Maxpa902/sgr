import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../modelos/usuario.dart';
import 'api_exception.dart';

/// Lo que devuelve el server al iniciar sesión o registrarse.
class SesionIniciada {
  const SesionIniciada({required this.token, required this.usuario});

  final String token;
  final Usuario usuario;
}

/// Habla con la API del server. Las pantallas no usan `http` directamente:
/// le piden todo a esta clase.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Token de la sesión actual. Si está cargado, se manda en cada pedido.
  String? token;

  static const _tiempoMaximo = Duration(seconds: 10);

  Future<SesionIniciada> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final json = await _post('/api/login', {
      'email': email,
      'password': password,
      'dispositivo': 'app',
    });
    return _sesionDesde(json);
  }

  Future<SesionIniciada> registrarse({
    required String nombre,
    required String apellido,
    required String dni,
    required String email,
    required String password,
    required String passwordConfirmacion,
    String? telefono,
  }) async {
    final json = await _post('/api/registro', {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmacion,
      'telefono': telefono,
      'dispositivo': 'app',
    });
    return _sesionDesde(json);
  }

  /// Los datos de la cuenta dueña del [token].
  Future<Usuario> usuarioActual() async {
    final json = await _get('/api/usuario');
    return Usuario.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Todas las cuentas, ordenadas por apellido y nombre. Disponible solo para admin.
  Future<List<Usuario>> listarUsuarios() async {
    final json = await _get('/api/usuarios');
    final data = json['data'];
    if (data is! List) {
      return [];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(Usuario.fromJson)
        .toList(growable: false);
  }

  /// Revoca el [token] en el server.
  Future<void> cerrarSesion() async {
    await _post('/api/logout');
  }

  SesionIniciada _sesionDesde(Map<String, dynamic> json) {
    return SesionIniciada(
      token: json['token'] as String,
      usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> _get(String ruta) {
    return _procesar(_http.get(_uri(ruta), headers: _encabezados()));
  }

  Future<Map<String, dynamic>> _post(
    String ruta, [
    Map<String, Object?>? cuerpo,
  ]) {
    return _procesar(
      _http.post(
        _uri(ruta),
        headers: _encabezados(conCuerpo: cuerpo != null),
        body: cuerpo == null ? null : jsonEncode(cuerpo),
      ),
    );
  }

  Uri _uri(String ruta) => Uri.parse('$baseUrl$ruta');

  Map<String, String> _encabezados({bool conCuerpo = false}) {
    return {
      'Accept': 'application/json',
      if (conCuerpo) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Espera la respuesta y devuelve su JSON, o lanza [ApiException].
  Future<Map<String, dynamic>> _procesar(Future<http.Response> pedido) async {
    final http.Response respuesta;
    try {
      respuesta = await pedido.timeout(_tiempoMaximo);
    } on TimeoutException {
      throw const ApiException.sinConexion();
    } on http.ClientException {
      throw const ApiException.sinConexion();
    }

    final json = _decodificar(respuesta);
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return json;
    }
    throw _errorDesde(respuesta.statusCode, json);
  }

  Map<String, dynamic> _decodificar(http.Response respuesta) {
    if (respuesta.bodyBytes.isEmpty) {
      return {};
    }
    try {
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
      return json is Map<String, dynamic> ? json : {};
    } on FormatException {
      return {};
    }
  }

  ApiException _errorDesde(int statusCode, Map<String, dynamic> json) {
    final mensajeDelServer = json['message'];

    return switch (statusCode) {
      401 => ApiException(
        'Tu sesión venció. Iniciá sesión de nuevo.',
        statusCode: statusCode,
      ),
      403 => ApiException(
        mensajeDelServer is String
            ? mensajeDelServer
            : 'No tenés permiso para hacer esto.',
        statusCode: statusCode,
      ),
      422 => ApiException(
        'Revisá los datos marcados.',
        statusCode: statusCode,
        errores: _primerErrorPorCampo(json['errors']),
      ),
      429 => ApiException(
        'Hiciste demasiados intentos. Esperá un minuto y probá de nuevo.',
        statusCode: statusCode,
      ),
      _ => ApiException(
        'Ocurrió un error en el servidor. Intentá de nuevo más tarde.',
        statusCode: statusCode,
      ),
    };
  }

  /// Laravel manda una lista de errores por campo; se muestra el primero.
  Map<String, String> _primerErrorPorCampo(Object? errores) {
    if (errores is! Map) {
      return {};
    }
    return {
      for (final MapEntry(:key, :value) in errores.entries)
        if (value is List && value.isNotEmpty) '$key': '${value.first}',
    };
  }
}
