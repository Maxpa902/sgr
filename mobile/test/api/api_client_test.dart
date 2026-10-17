import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/api/api_exception.dart';

import '../helpers.dart';

void main() {
  test(
    'logs in sending the credentials as JSON and returns token and user',
    () async {
      late http.Request pedido;
      final api = clienteDePrueba((request) async {
        pedido = request;
        return respuestaJson({'token': '1|abc', 'usuario': usuarioJson()}, 200);
      });

      final sesion = await api.iniciarSesion(
        email: 'ana@example.com',
        password: 'secreta123',
      );

      expect(sesion.token, '1|abc');
      expect(sesion.usuario.nombre, 'Ana');
      expect(pedido.method, 'POST');
      expect(pedido.url, Uri.parse('http://server/api/login'));
      expect(pedido.headers['Accept'], 'application/json');
      expect(jsonDecode(pedido.body), containsPair('email', 'ana@example.com'));
    },
  );

  test('sends the token as a Bearer header once it is set', () async {
    late http.Request pedido;
    final api = clienteDePrueba((request) async {
      pedido = request;
      return respuestaJson({'data': usuarioJson()}, 200);
    })..token = '1|abc';

    await api.usuarioActual();

    expect(pedido.headers['Authorization'], 'Bearer 1|abc');
  });

  test(
    'asks for the map claims with the chosen states and categories',
    () async {
      late http.Request pedido;
      final api = clienteDePrueba((request) async {
        pedido = request;
        return respuestaJson({
          'data': [reclamoJson(titulo: 'Cable caído')],
        }, 200);
      });

      final reclamos = await api.reclamosDelMapa(
        estados: {'pendiente', 'resuelto'},
        tipos: {3},
      );

      expect(reclamos.single.titulo, 'Cable caído');
      expect(pedido.url.path, '/api/reclamos');
      expect(pedido.url.queryParametersAll['estados[]'], [
        'pendiente',
        'resuelto',
      ]);
      expect(pedido.url.queryParametersAll['tipos[]'], ['3']);
    },
  );

  test('turns a 422 response into the first error of each field', () async {
    final api = clienteDePrueba(
      (_) async => respuestaJson({
        'message': 'Ya existe una cuenta con ese email. (y 1 error más)',
        'errors': {
          'email': ['Ya existe una cuenta con ese email.'],
          'dni': ['Ya existe una cuenta con ese DNI.', 'Otro error del DNI.'],
        },
      }, 422),
    );

    await expectLater(
      api.iniciarSesion(email: 'ana@example.com', password: 'secreta123'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.mensaje, 'mensaje', 'Revisá los datos marcados.')
            .having((e) => e.errores, 'errores', {
              'email': 'Ya existe una cuenta con ese email.',
              'dni': 'Ya existe una cuenta con ese DNI.',
            }),
      ),
    );
  });

  test('explains too many attempts in Spanish', () async {
    final api = clienteDePrueba(
      (_) async => respuestaJson({'message': 'Too Many Attempts.'}, 429),
    );

    await expectLater(
      api.iniciarSesion(email: 'ana@example.com', password: 'secreta123'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          'Hiciste demasiados intentos. Esperá un minuto y probá de nuevo.',
        ),
      ),
    );
  });

  test('reports no connection when the server cannot be reached', () async {
    final api = clienteDePrueba(sinServer);

    await expectLater(
      api.usuarioActual(),
      throwsA(
        isA<ApiException>().having((e) => e.sinConexion, 'sinConexion', isTrue),
      ),
    );
  });
}
