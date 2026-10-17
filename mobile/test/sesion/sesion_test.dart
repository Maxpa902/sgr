import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/sesion/sesion.dart';

import '../helpers.dart';

void main() {
  test('starts without a session when no token is stored', () async {
    final sesion = sesionDePrueba(
      (_) async => fail('No debería consultar al server.'),
    );

    await sesion.restaurar();

    expect(sesion.estado, EstadoSesion.sinSesion);
  });

  test('restores the session when the stored token is still valid', () async {
    final sesion = sesionDePrueba(
      (_) async => respuestaJson({'data': usuarioJson()}, 200),
      almacen: AlmacenTokenEnMemoria('1|abc'),
    );

    await sesion.restaurar();

    expect(sesion.estado, EstadoSesion.conSesion);
    expect(sesion.usuario?.nombre, 'Ana');
  });

  test('forgets the stored token when the server rejects it', () async {
    final almacen = AlmacenTokenEnMemoria('1|vencido');
    final sesion = sesionDePrueba(
      (_) async => respuestaJson({'message': 'Unauthenticated.'}, 401),
      almacen: almacen,
    );

    await sesion.restaurar();

    expect(sesion.estado, EstadoSesion.sinSesion);
    expect(almacen.token, isNull);
  });

  test('keeps the stored token when the server does not answer', () async {
    final almacen = AlmacenTokenEnMemoria('1|abc');
    final sesion = sesionDePrueba(sinServer, almacen: almacen);

    await sesion.restaurar();

    expect(sesion.estado, EstadoSesion.sinConexion);
    expect(almacen.token, '1|abc');
  });

  test('saves the token after logging in', () async {
    final almacen = AlmacenTokenEnMemoria();
    final sesion = sesionDePrueba(
      (_) async =>
          respuestaJson({'token': '1|nuevo', 'usuario': usuarioJson()}, 200),
      almacen: almacen,
    );

    await sesion.iniciarSesion(
      email: 'ana@example.com',
      password: 'secreta123',
    );

    expect(sesion.estado, EstadoSesion.conSesion);
    expect(almacen.token, '1|nuevo');
  });

  test(
    'closes the session on the phone even if the server does not answer',
    () async {
      final almacen = AlmacenTokenEnMemoria('1|abc');
      final sesion = sesionDePrueba(sinServer, almacen: almacen);

      await sesion.cerrarSesion();

      expect(sesion.estado, EstadoSesion.sinSesion);
      expect(almacen.token, isNull);
    },
  );
}
