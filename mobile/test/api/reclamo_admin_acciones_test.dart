import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/api/api_exception.dart';

import '../helpers.dart';

void main() {
  test('asigna el responsable elegido con la sesión autenticada', () async {
    late http.Request pedido;
    final api = clienteDePrueba((request) async {
      pedido = request;
      return respuestaJson({'data': {}}, 200);
    })..token = 'token-admin';

    await api.asignarReclamo(28, 9);

    expect(pedido.method, 'POST');
    expect(pedido.url.path, '/api/reclamos/28/asignacion');
    expect(pedido.headers['Authorization'], 'Bearer token-admin');
    expect(jsonDecode(pedido.body), {'responsable_id': 9});
  });

  test('desasigna mediante DELETE', () async {
    late http.Request pedido;
    final api = clienteDePrueba((request) async {
      pedido = request;
      return respuestaJson({'data': {}}, 200);
    });

    await api.desasignarReclamo(28);

    expect(pedido.method, 'DELETE');
    expect(pedido.url.path, '/api/reclamos/28/asignacion');
    expect(pedido.body, isEmpty);
  });

  test('rechaza con motivo y decisión explícita sobre falsedad', () async {
    late http.Request pedido;
    final api = clienteDePrueba((request) async {
      pedido = request;
      return respuestaJson({'data': {}}, 200);
    });

    await api.rechazarReclamo(
      28,
      observacion: 'El reporte es falso',
      esFalso: true,
    );

    expect(pedido.method, 'POST');
    expect(pedido.url.path, '/api/reclamos/28/rechazar');
    expect(jsonDecode(pedido.body), {
      'observacion': 'El reporte es falso',
      'es_falso': true,
    });
  });

  test('propaga el conflicto si el estado cambió antes de asignar', () async {
    final api = clienteDePrueba(
      (_) async =>
          respuestaJson({'message': 'El reclamo ya no está pendiente.'}, 409),
    );

    await expectLater(
      api.asignarReclamo(28, 9),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('interpreta responsable y cierre del detalle administrativo', () async {
    final api = clienteDePrueba(
      (_) async => respuestaJson({
        'data': {
          'id': 28,
          'titulo': 'Alumbrado',
          'descripcion': 'Lámpara apagada',
          'latitud': -45.8,
          'longitud': -67.5,
          'tipo': tipoJson(),
          'estado': 'rechazado',
          'creador': 'Ana Pérez',
          'email_creador': 'ana@example.com',
          'creado_en': '2026-10-22T12:30:00Z',
          'fotos': <String>[],
          'responsable': {'id': 9, 'nombre': 'Luis', 'apellido': 'Paz'},
          'cierre': {
            'observacion': 'Duplicado',
            'creado_en': '2026-10-23T12:30:00Z',
            'autor': {'id': 2, 'nombre': 'Eva', 'apellido': 'Díaz'},
          },
        },
      }, 200),
    );

    final detalle = await api.obtenerReclamoAdmin(28);

    expect(detalle.responsable?.id, 9);
    expect(detalle.responsable?.nombreCompleto, 'Luis Paz');
    expect(detalle.cierre?.observacion, 'Duplicado');
    expect(detalle.cierre?.autor?.nombreCompleto, 'Eva Díaz');
    expect(detalle.cierre?.creadoEn, DateTime.utc(2026, 10, 23, 12, 30));
  });
}
