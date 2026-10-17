import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/sesion/almacen_token.dart';
import 'package:mobile/sesion/sesion.dart';

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
