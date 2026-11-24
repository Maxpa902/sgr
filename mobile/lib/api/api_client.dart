import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../modelos/cambio_de_estado.dart';
import '../modelos/comentario.dart';
import '../modelos/reclamo_mapa.dart';
import '../modelos/reclamo_admin.dart';
import '../modelos/reclamo_detalle_admin.dart';
import '../modelos/sancion.dart';
import '../modelos/tipo_reclamo.dart';
import '../modelos/usuario.dart';
import 'api_exception.dart';

/// Lo que devuelve el server al iniciar sesión o registrarse.
class SesionIniciada {
  const SesionIniciada({required this.token, required this.usuario});

  final String token;
  final Usuario usuario;
}

class DetalleReclamoVecino {
  const DetalleReclamoVecino({
    required this.reclamo,
    required this.puedeEditar,
    required this.puedeEliminar,
    required this.puedeVotar,
  });
  final ReclamoMapa reclamo;
  final bool puedeEditar;
  final bool puedeEliminar;
  final bool puedeVotar;
}

/// Un bloque de cuentas y el cursor para solicitar el siguiente.
class PaginaUsuarios {
  const PaginaUsuarios({
    required this.usuarios,
    required this.total,
    required this.proximoCursor,
  });

  final List<Usuario> usuarios;
  final int total;
  final String? proximoCursor;
}

/// Un bloque de reclamos y el cursor para solicitar el siguiente.
class PaginaReclamosAdmin {
  const PaginaReclamosAdmin({
    required this.reclamos,
    required this.total,
    required this.proximoCursor,
  });

  final List<ReclamoAdmin> reclamos;
  final int total;
  final String? proximoCursor;
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

  /// Crea una cuenta interna sin modificar la sesión actual.
  Future<void> crearCuentaInterna({
    required String nombre,
    required String apellido,
    required String dni,
    required String email,
    required String password,
    required String passwordConfirmacion,
    required String rol,
    String? telefono,
  }) async {
    await _post('/api/usuarios', {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmacion,
      'rol': rol,
      'telefono': telefono,
    });
  }

  /// Los datos de la cuenta dueña del [token].
  Future<Usuario> usuarioActual() async {
    final json = await _get('/api/usuario');
    return Usuario.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Actualiza los datos personales y opcionalmente la contraseña del usuario logueado.
  Future<Usuario> actualizarPerfil({
    required String nombre,
    required String apellido,
    required String email,
    String? telefono,
    String? passwordActual,
    String? password,
    String? passwordConfirmacion,
  }) async {
    final cuerpo = <String, Object?>{
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'telefono': telefono,
    };

    if (password != null && password.isNotEmpty) {
      cuerpo['password_actual'] = passwordActual;
      cuerpo['password'] = password;
      cuerpo['password_confirmation'] = passwordConfirmacion;
    }

    final json = await _put('/api/usuario', cuerpo);
    return Usuario.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Obtiene la lista de usuarios con sanciones ordenados de mayor a menor.
  Future<List<Usuario>> listarUsuariosConSanciones() async {
    final json = await _get('/api/admin/usuarios-sancionados');
    final data = json['data'] as List? ?? json as List? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Usuario.fromJson)
        .toList(growable: false);
  }

  /// Todas las sanciones de un vecino (activas, terminadas y revocadas).
  Future<SancionesDeVecino> listarSancionesDeVecino(int usuarioId) async {
    final json = await _get('/api/admin/usuarios/$usuarioId/sanciones');
    return SancionesDeVecino.fromJson(json);
  }

  /// Revoca una sanción; el server recalcula la suspensión del vecino.
  Future<void> revocarSancion(int sancionId, {required String motivo}) async {
    await _post('/api/admin/sanciones/$sancionId/revocar', {'motivo': motivo});
  }

  /// Un bloque de cuentas filtrado, ordenado por apellido y nombre.
  Future<PaginaUsuarios> listarUsuarios({
    String? busqueda,
    String? rol,
    String? estado,
    String? suspension,
    String? cursor,
  }) async {
    final parametros = <String, Object>{};
    if (busqueda != null && busqueda.isNotEmpty) {
      parametros['q'] = busqueda;
    }
    if (rol != null) {
      parametros['rol'] = rol;
    }
    if (estado != null) {
      parametros['estado'] = estado;
    }
    if (suspension != null) {
      parametros['suspension'] = suspension;
    }
    if (cursor != null) {
      parametros['cursor'] = cursor;
    }

    final json = await _get('/api/usuarios', parametros: parametros);
    final data = json['data'] as List? ?? const [];
    final metadata = json['meta'] as Map<String, dynamic>? ?? const {};
    return PaginaUsuarios(
      usuarios: data
          .whereType<Map<String, dynamic>>()
          .map(Usuario.fromJson)
          .toList(growable: false),
      total: (metadata['total'] as num?)?.toInt() ?? data.length,
      proximoCursor: metadata['next_cursor'] as String?,
    );
  }

  /// Listar usuarios para el panel de administración de cuentas.
  Future<PaginaUsuarios> listarUsuariosAdmin({
    String? busqueda,
    String? rol,
    String? estado,
    String? cursor,
  }) async {
    final parametros = <String, Object>{};
    if (busqueda != null && busqueda.isNotEmpty) parametros['q'] = busqueda;
    if (rol != null) parametros['rol'] = rol;
    if (estado != null) parametros['estado'] = estado;
    if (cursor != null) parametros['cursor'] = cursor;

    final json = await _get('/api/admin/usuarios', parametros: parametros);
    final data = json['data'] as List? ?? const [];
    final metadata = json['meta'] as Map<String, dynamic>? ?? const {};
    return PaginaUsuarios(
      usuarios: data
          .whereType<Map<String, dynamic>>()
          .map(Usuario.fromJson)
          .toList(growable: false),
      total: (metadata['total'] as num?)?.toInt() ?? data.length,
      proximoCursor: metadata['next_cursor'] as String?,
    );
  }

  /// Actualizar el rol o estado de una cuenta (Admin).
  Future<void> actualizarCuenta(
    int usuarioId, {
    bool? activo,
    String? rol,
  }) async {
    final datos = <String, dynamic>{
      if (activo != null) 'activo': activo,
      if (rol != null) 'rol': rol,
    };
    final uri = _uri('/api/usuarios/$usuarioId');
    await _procesar(
      _http.patch(
        uri,
        headers: _encabezados(conCuerpo: true),
        body: jsonEncode(datos),
      ),
      metodo: 'PATCH',
      uri: uri,
    );
  }

  /// Crear una nueva categoría de reclamo (Admin).
  Future<void> crearCategoria({
    required String nombre,
    String? descripcion,
    String? icono,
  }) async {
    await _post('/api/admin/tipos-reclamo', {
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (icono != null) 'icono': icono,
    });
  }

  /// Actualizar una categoría existente (Admin).
  Future<void> actualizarCategoria(
    int id, {
    required String nombre,
    String? descripcion,
    String? icono,
    bool? activo,
  }) async {
    // Si usas PUT en tu API:
    final uri = _uri('/api/admin/tipos-reclamo/$id');
    await _procesar(
      _http.put(
        uri,
        headers: _encabezados(conCuerpo: true),
        body: jsonEncode({
          'nombre': nombre,
          if (descripcion != null) 'descripcion': descripcion,
          if (icono != null) 'icono': icono,
          if (activo != null) 'activo': activo,
        }),
      ),
      metodo: 'PUT',
      uri: uri,
    );
  }

  /// Activar o desactivar una categoría (Admin).
  Future<void> toggleActivoCategoria(int id, bool activo) async {
    await _post('/api/admin/tipos-reclamo/$id/activo', {'activo': activo});
  }

  /// Lista reclamos para el panel de admin, con búsqueda, filtros y cursor.
  Future<PaginaReclamosAdmin> listarReclamosAdmin({
    String? busqueda,
    String? estado,
    int? tipoId,
    bool urgentes = false,
    bool incluirBajas = false,
    String? cursor,
  }) async {
    final parametros = <String, Object>{};
    if (busqueda != null && busqueda.isNotEmpty) parametros['q'] = busqueda;
    if (estado != null) parametros['estado'] = estado;
    if (tipoId != null) parametros['tipo'] = '$tipoId';
    if (urgentes) parametros['urgentes'] = '1';
    if (incluirBajas) parametros['incluir_bajas'] = '1';
    if (cursor != null) parametros['cursor'] = cursor;

    final json = await _get('/api/admin/reclamos', parametros: parametros);
    final data = json['data'] as List? ?? const [];
    final metadata = json['meta'] as Map<String, dynamic>? ?? const {};
    return PaginaReclamosAdmin(
      reclamos: data
          .whereType<Map<String, dynamic>>()
          .map(ReclamoAdmin.fromJson)
          .toList(growable: false),
      total: (metadata['total'] as num?)?.toInt() ?? data.length,
      proximoCursor: metadata['next_cursor'] as String?,
    );
  }

  /// Obtiene los datos completos de un reclamo para la vista de administración.
  Future<ReclamoDetalleAdmin> obtenerReclamoAdmin(int id) async {
    final json = await _get('/api/admin/reclamos/$id');
    return ReclamoDetalleAdmin.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Reclamos propios o disponibles para el personal operativo.
  Future<PaginaReclamosAdmin> listarTrabajo({
    required String vista,
    String? cursor,
  }) async {
    final parametros = <String, Object>{'vista': vista};
    if (cursor != null) parametros['cursor'] = cursor;
    final json = await _get('/api/trabajo/reclamos', parametros: parametros);
    final data = json['data'] as List? ?? const [];
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return PaginaReclamosAdmin(
      reclamos: data
          .whereType<Map<String, dynamic>>()
          .map(ReclamoAdmin.fromJson)
          .toList(growable: false),
      total: (meta['total'] as num?)?.toInt() ?? data.length,
      proximoCursor: meta['next_cursor'] as String?,
    );
  }

  Future<ReclamoDetalleAdmin> obtenerReclamoTrabajo(int id) async {
    final json = await _get('/api/trabajo/reclamos/$id');
    return ReclamoDetalleAdmin.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> comenzarReclamo(int id) async {
    await _post('/api/reclamos/$id/comenzar', {});
  }

  Future<void> finalizarReclamo(
    int id, {
    required String observacion,
    required String visibilidad,
  }) async {
    await _post('/api/reclamos/$id/finalizar', {
      'observacion': observacion,
      'visibilidad': visibilidad,
    });
  }

  Future<void> asignarReclamo(int id, int responsableId) async {
    await _post('/api/reclamos/$id/asignacion', {
      'responsable_id': responsableId,
    });
  }

  Future<void> desasignarReclamo(int id) async {
    final uri = _uri('/api/reclamos/$id/asignacion');
    await _procesar(
      _http.delete(uri, headers: _encabezados()),
      metodo: 'DELETE',
      uri: uri,
    );
  }

  Future<void> rechazarReclamo(
    int id, {
    required String observacion,
    required bool esFalso,
  }) async {
    await _post('/api/reclamos/$id/rechazar', {
      'observacion': observacion,
      'es_falso': esFalso,
    });
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

  /// Categorías activas e inactivas para los filtros de administración.
  Future<List<TipoReclamo>> tiposDeReclamoAdmin() async {
    final json = await _get('/api/admin/tipos-reclamo');
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
        _reclamoDesdeJson(reclamo as Map<String, dynamic>),
    ];
  }

  Future<DetalleReclamoVecino> detalleReclamoVecino(int id) async {
    final json = await _get('/api/reclamos/$id');
    final data = json['data'] as Map<String, dynamic>;
    return DetalleReclamoVecino(
      reclamo: _reclamoDesdeJson(data),
      puedeEditar: data['puede_editar'] == true,
      puedeEliminar: data['puede_eliminar'] == true,
      puedeVotar: data['puede_votar'] == true,
    );
  }

  /// Devuelve los reclamos creados por el usuario autenticado o en los que participó.
  Future<List<ReclamoMapa>> misReclamos() async {
    final json = await _get('/api/reclamos', parametros: {'mis_reclamos': '1'});
    return [
      for (final reclamo in json['data'] as List)
        _reclamoDesdeJson(reclamo as Map<String, dynamic>),
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
      request.files.add(await http.MultipartFile.fromPath('foto', imagen.path));
    }

    final response = await _procesar(
      http.Response.fromStream(await request.send()),
      metodo: request.method,
      uri: uri,
    );

    return _reclamoDesdeJson(response['data'] as Map<String, dynamic>);
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
    final uri = _uri('/api/reclamos/$id');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_encabezados())
      ..fields['_method'] = 'PUT'
      ..fields['titulo'] = titulo
      ..fields['descripcion'] = descripcion
      ..fields['latitud'] = '$latitud'
      ..fields['longitud'] = '$longitud';

    for (var i = 0; i < fotosEliminar.length; i++) {
      request.fields['fotos_eliminar[$i]'] = '${fotosEliminar[i]}';
    }

    for (final imagen in nuevasImagenes) {
      request.files.add(
        await http.MultipartFile.fromPath('fotos[]', imagen.path),
      );
    }

    final response = await _procesar(
      http.Response.fromStream(await request.send()),
      metodo: 'PUT',
      uri: uri,
    );

    return _reclamoDesdeJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> eliminarReclamo(int id) async {
    final uri = _uri('/api/reclamos/$id');
    await _procesar(
      _http.delete(uri, headers: _encabezados()),
      metodo: 'DELETE',
      uri: uri,
    );
  }

  /// Seguimiento público: los cambios de estado, del más viejo al más nuevo.
  Future<List<CambioDeEstado>> seguimientoDeReclamo(int reclamoId) async {
    final json = await _get('/api/reclamos/$reclamoId/historial');
    final data = json['data'] as List? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(CambioDeEstado.fromJson)
        .toList(growable: false);
  }

  Future<ComentariosDeReclamo> listarComentarios(int reclamoId) async {
    final json = await _get('/api/reclamos/$reclamoId/comentarios');
    return ComentariosDeReclamo.fromJson(json);
  }

  Future<void> crearComentario(int reclamoId, String contenido) async {
    await _post('/api/reclamos/$reclamoId/comentarios', {
      'contenido': contenido,
    });
  }

  Future<void> editarComentario(int comentarioId, String contenido) async {
    final uri = _uri('/api/comentarios/$comentarioId');
    await _procesar(
      _http.patch(
        uri,
        headers: _encabezados(conCuerpo: true),
        body: jsonEncode({'contenido': contenido}),
      ),
      metodo: 'PATCH',
      uri: uri,
    );
  }

  Future<void> borrarComentario(int comentarioId) async {
    final uri = _uri('/api/comentarios/$comentarioId');
    await _procesar(
      _http.delete(uri, headers: _encabezados()),
      metodo: 'DELETE',
      uri: uri,
    );
  }

  Future<List<Map<String, dynamic>>> obtenerVotantes(int reclamoId) async {
    final json = await _get('/api/reclamos/$reclamoId/votos');
    final data = json['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> votarReclamo(int reclamoId, String valor) async {
    return await _post('/api/reclamos/$reclamoId/votar', {'valor': valor});
  }

  SesionIniciada _sesionDesde(Map<String, dynamic> json) {
    return SesionIniciada(
      token: json['token'] as String,
      usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }

  ReclamoMapa _reclamoDesdeJson(Map<String, dynamic> json) {
    final copia = Map<String, dynamic>.from(json);

    if (copia['fotos'] is List) {
      copia['fotos'] = [
        for (final f in copia['fotos'] as List)
          _normalizarUrlFoto(f.toString()),
      ];
    }

    if (copia['fotos_detalle'] is List) {
      copia['fotos_detalle'] = [
        for (final f in copia['fotos_detalle'] as List)
          if (f is Map<String, dynamic>)
            {'id': f['id'], 'url': _normalizarUrlFoto(f['url'].toString())},
      ];
    }

    return ReclamoMapa.fromJson(copia);
  }

  String _normalizarUrlFoto(String url) {
    final uriFoto = Uri.tryParse(url);
    final uriBase = Uri.tryParse(baseUrl);
    if (uriFoto == null || uriBase == null) return url;

    if (uriFoto.path.startsWith('/storage/')) {
      return uriBase.replace(path: uriFoto.path).toString();
    }
    return url;
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

  Future<Map<String, dynamic>> _put(
    String ruta, [
    Map<String, Object?>? cuerpo,
  ]) {
    final uri = _uri(ruta);
    return _procesar(
      _http.put(
        uri,
        headers: _encabezados(conCuerpo: cuerpo != null),
        body: cuerpo == null ? null : jsonEncode(cuerpo),
      ),
      metodo: 'PUT',
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
    final linea =
        '${DateTime.now().toIso8601String()} '
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
        todosLosErrores: _todosLosErroresPorCampo(json['errors']),
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

  Map<String, List<String>> _todosLosErroresPorCampo(Object? errores) {
    if (errores is! Map) return {};
    return {
      for (final MapEntry(:key, :value) in errores.entries)
        if (value is List && value.isNotEmpty)
          '$key': value.whereType<String>().toList(),
    };
  }
}
