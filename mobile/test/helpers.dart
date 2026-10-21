import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/sesion/almacen_token.dart';
import 'package:mobile/sesion/sesion.dart';
import 'package:mobile/ubicacion/servicio_ubicacion.dart';

/// Guarda el token en una variable, en lugar del almacenamiento del celular.
class AlmacenTokenEnMemoria implements AlmacenToken {
  AlmacenTokenEnMemoria([this.token]);

  String? token;

  @override
  Future<String?> leer() async => token;

  @override
  Future<void> guardar(String token) async => this.token = token;

  @override
  Future<void> borrar() async => token = null;
}

/// Un usuario como lo devuelve la API.
Map<String, dynamic> usuarioJson({String nombre = 'Ana'}) {
  return {
    'id': 7,
    'nombre': nombre,
    'apellido': 'Pérez',
    'email': 'ana@example.com',
    'telefono': null,
    'rol': 'ciudadano',
    'suspendido_hasta': null,
  };
}

/// Una categoría como la devuelve la API.
Map<String, dynamic> tipoJson({
  int id = 1,
  String nombre = 'Energía eléctrica',
  String? icono = 'electricidad',
}) {
  return {'id': id, 'nombre': nombre, 'descripcion': null, 'icono': icono};
}

/// Un reclamo del mapa como lo devuelve la API. Por defecto, en el centro.
Map<String, dynamic> reclamoJson({
  int id = 1,
  String titulo = 'Cable caído',
  double latitud = -45.8630,
  double longitud = -67.4856,
  String? direccion = 'Centro',
  String estado = 'pendiente',
  int confirmaciones = 0,
  int desmentidas = 0,
  Map<String, dynamic>? tipo,
}) {
  return {
    'id': id,
    'titulo': titulo,
    'latitud': latitud,
    'longitud': longitud,
    'direccion': direccion,
    'tipo': tipo ?? tipoJson(),
    'estado': estado,
    'confirmaciones': confirmaciones,
    'desmentidas': desmentidas,
    'created_at': DateTime.now()
        .subtract(const Duration(hours: 3))
        .toUtc()
        .toIso8601String(),
  };
}

/// Un server simulado que responde según la ruta del pedido.
MockClientHandler servidorConRutas(Map<String, MockClientHandler> rutas) {
  return (pedido) async {
    final responder = rutas[pedido.url.path];
    if (responder == null) {
      return respuestaJson({'message': 'Not Found.'}, 404);
    }
    return responder(pedido);
  };
}

/// Un GPS simulado: devuelve [punto] o lanza [error].
class UbicacionSimulada implements ServicioUbicacion {
  UbicacionSimulada({this.punto, this.error});

  final LatLng? punto;
  final UbicacionException? error;

  @override
  Future<LatLng> ubicacionActual() async {
    if (error case final error?) {
      throw error;
    }
    return punto!;
  }
}

http.Response respuestaJson(Object? cuerpo, int statusCode) {
  return http.Response(
    jsonEncode(cuerpo),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Simula que el server está apagado.
Future<http.Response> sinServer(http.Request pedido) async {
  throw http.ClientException('Connection refused', pedido.url);
}

ApiClient clienteDePrueba(MockClientHandler server) {
  return ApiClient(baseUrl: 'http://server', httpClient: MockClient(server));
}

/// Una sesión conectada a un server simulado.
Sesion sesionDePrueba(MockClientHandler server, {AlmacenToken? almacen}) {
  return Sesion(
    api: clienteDePrueba(server),
    almacen: almacen ?? AlmacenTokenEnMemoria(),
  );
}
