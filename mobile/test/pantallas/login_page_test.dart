import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pantallas/login_page.dart';
import 'package:mobile/sesion/sesion.dart';

import '../helpers.dart';

void main() {
  Future<void> mostrarLogin(WidgetTester tester, Sesion sesion) {
    return tester.pumpWidget(MaterialApp(home: LoginPage(sesion: sesion)));
  }

  Future<void> ingresar(WidgetTester tester, {required String password}) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ana@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      password,
    );
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for email and password before contacting the server', (
    tester,
  ) async {
    var pedidos = 0;
    final sesion = sesionDePrueba((_) async {
      pedidos++;
      return respuestaJson({}, 200);
    });
    await mostrarLogin(tester, sesion);

    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresá tu email.'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña.'), findsOneWidget);
    expect(pedidos, 0);
  });

  testWidgets('shows the server message when the credentials are wrong', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      (_) async => respuestaJson({
        'message': 'El email o la contraseña no son correctos.',
        'errors': {
          'email': ['El email o la contraseña no son correctos.'],
        },
      }, 422),
    );
    await mostrarLogin(tester, sesion);

    await ingresar(tester, password: 'incorrecta');

    expect(
      find.text('El email o la contraseña no son correctos.'),
      findsOneWidget,
    );
    expect(sesion.estado, isNot(EstadoSesion.conSesion));
  });

  testWidgets('starts the session when the credentials are right', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      (_) async =>
          respuestaJson({'token': '1|abc', 'usuario': usuarioJson()}, 200),
    );
    await mostrarLogin(tester, sesion);

    await ingresar(tester, password: 'secreta123');

    expect(sesion.estado, EstadoSesion.conSesion);
  });
}
