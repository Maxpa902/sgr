import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../modelos/reclamo_mapa.dart';
import '../modelos/tipo_reclamo.dart';
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
  Future<void> _escriturasDelLog = Future<void>.value();

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

  /// Las categorías que se ofrecen para cargar y filtrar reclamos.
  Future<List<TipoReclamo>> tiposDeReclamo() async {
    final json = await _get('/api/tipos-reclamo');
    return [
      for (final tipo in json['data'] as List)
        TipoReclamo.fromJson(tipo as Map<String, dynamic>),
    ];
  }

  /// Los reclamos públicos para el mapa, en alguno de los [estados].
  /// Si se pasan [tipos], solo los de esas categorías.
  Future<List<ReclamoMapa>> reclamosDelMapa({
    required Set<String> estados,
    Set<int>? tipos,
  }) async {
    final json = await _get(
      '/api/reclamos',
      parametros: {
        'estados[]': estados.toList(),
        if (tipos != null) 'tipos[]': [for (final tipo in tipos) '$tipo'],
      },
    );
    return [
      for (final reclamo in json['data'] as List)
        ReclamoMapa.fromJson(reclamo as Map<String, dynamic>),
    ];
  }

  /// Devuelve los reclamos creados por el usuario autenticado o en los que participó.
  Future<List<ReclamoMapa>> misReclamos() async {
    final json = await _get('/api/reclamos', parametros: {'mis_reclamos': '1'});
    return [
      for (final reclamo in json['data'] as List)
        ReclamoMapa.fromJson(reclamo as Map<String, dynamic>),
    ];
  }

  Future<ReclamoMapa> crearReclamo({
    required String titulo,
    required String descripcion,
    required int tipoId,
    required double latitud,
    required double longitud,
    File? imagen,
    bool forzarCreacion = false,
  }) async {
    final uri = _uri('/api/reclamos');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_encabezados())
      ..fields['titulo'] = titulo
      ..fields['descripcion'] = descripcion
      ..fields['tipo_reclamo_id'] = '$tipoId'
      ..fields['latitud'] = '$latitud'
      ..fields['longitud'] = '$longitud';

    if (forzarCreacion) {
      request.fields['forzar_creacion'] = '1';
    }

    if (imagen != null) {
      request.files.add(
        await http.MultipartFile.fromPath('foto', imagen.path),
      );
    }

    final response = await _procesar(
      http.Response.fromStream(await request.send()),
      metodo: request.method,
      uri: uri,
    );

    return ReclamoMapa.fromJson(response['data'] as Map<String, dynamic>);
  }

 
  Future<List<Map<String, dynamic>>> obtenerVotantes(int reclamoId) async {
    final json = await _get('/api/reclamos/$reclamoId/votos'); 
    final data = json['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> votarReclamo(int reclamoId, String valor) async {
    return await _post('/api/reclamos/$reclamoId/votar', {
      'valor': valor,
    });
  }

  SesionIniciada _sesionDesde(Map<String, dynamic> json) {
    return SesionIniciada(
      token: json['token'] as String,
      usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> _get(
    String ruta, {
    Map<String, Object>? parametros,
  }) {
    final uri = _uri(ruta, parametros);
    return _procesar(
      _http.get(uri, headers: _encabezados()),
      metodo: 'GET',
      uri: uri,
    );
  }

  Future<Map<String, dynamic>> _post(
    String ruta, [
    Map<String, Object?>? cuerpo,
  ]) {
    final uri = _uri(ruta);
    return _procesar(
      _http.post(
        uri,
        headers: _encabezados(conCuerpo: cuerpo != null),
        body: cuerpo == null ? null : jsonEncode(cuerpo),
      ),
      metodo: 'POST',
      uri: uri,
    );
  }

  /// Arma la dirección completa. Los [parametros] van después del `?`; un valor
  /// que es una lista se repite: `estados[]=pendiente&estados[]=resuelto`.
  Uri _uri(String ruta, [Map<String, Object>? parametros]) {
    final uri = Uri.parse('$baseUrl$ruta');
    return parametros == null ? uri : uri.replace(queryParameters: parametros);
  }

  Map<String, String> _encabezados({bool conCuerpo = false}) {
    return {
      'Accept': 'application/json',
      if (conCuerpo) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Espera la respuesta y devuelve su JSON, o lanza [ApiException].
  Future<Map<String, dynamic>> _procesar(
    Future<http.Response> pedido, {
    required String metodo,
    required Uri uri,
  }) async {
    final cronometro = Stopwatch()..start();
    final http.Response respuesta;
    try {
      respuesta = await pedido.timeout(_tiempoMaximo);
    } on TimeoutException {
      _registrarTiempo(metodo, uri, cronometro, resultado: 'timeout');
      throw const ApiException.sinConexion();
    } on http.ClientException {
      _registrarTiempo(metodo, uri, cronometro, resultado: 'sin conexión');
      throw const ApiException.sinConexion();
    }

    _registrarTiempo(
      metodo,
      uri,
      cronometro,
      resultado: '${respuesta.statusCode}',
    );
    final json = _decodificar(respuesta);
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return json;
    }
    throw _errorDesde(respuesta.statusCode, json);
  }

  void _registrarTiempo(
    String metodo,
    Uri uri,
    Stopwatch cronometro, {
    required String resultado,
  }) {
    cronometro.stop();
    // Evita incluir parámetros que podrían contener datos sensibles.
    final linea = '${DateTime.now().toIso8601String()} '
        '$metodo ${uri.path} - ${cronometro.elapsedMilliseconds} ms '
        '(resultado: $resultado)\n';
    _escriturasDelLog = _escriturasDelLog.then((_) async {
      try {
        final directorio = await getApplicationDocumentsDirectory();
        final archivo = File('${directorio.path}/api_requests.log');
        await archivo.writeAsString(linea, mode: FileMode.append, flush: true);
        debugPrint('[API] $linea');
      } on Object catch (error) {
        debugPrint('[API] No se pudo guardar api_requests.log: $error');
      }
    });
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

    ReclamoMapa? duplicado;
    if (json['reclamo_duplicado'] is Map<String, dynamic>) {
      duplicado = ReclamoMapa.fromJson(
        json['reclamo_duplicado'] as Map<String, dynamic>,
      );
    }

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
      409 => ApiException(
        mensajeDelServer is String
            ? mensajeDelServer
            : 'Ya existe un reclamo activo cerca de esta ubicación.',
        statusCode: statusCode,
        reclamoDuplicado: duplicado,
      ),
      422 => ApiException(
        mensajeDelServer is String
            ? mensajeDelServer
            : 'Revisá los datos marcados.',
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
