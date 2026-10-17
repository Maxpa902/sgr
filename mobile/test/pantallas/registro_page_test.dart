import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pantallas/registro_page.dart';
import 'package:mobile/sesion/sesion.dart';

import '../helpers.dart';

void main() {
  /// Abre el registro encima de otra pantalla, como pasa en la app real.
  Future<void> mostrarRegistro(WidgetTester tester, Sesion sesion) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Pantalla anterior'))),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(builder: (_) => RegistroPage(sesion: sesion)),
        );
    await tester.pumpAndSettle();
  }

  Future<void> completarFormulario(
    WidgetTester tester, {
    String dni = '30111222',
    String repetirPassword = 'secreta123',
  }) async {
    final campos = {
      'Nombre': 'Ana',
      'Apellido': 'Pérez',
      'DNI': dni,
      'Email': 'ana@example.com',
      'Contraseña': 'secreta123',
      'Repetir contraseña': repetirPassword,
    };
    for (final MapEntry(key: etiqueta, value: valor) in campos.entries) {
      await tester.enterText(
        find.widgetWithText(TextFormField, etiqueta),
        valor,
      );
    }
  }

  Future<void> tocarCrearCuenta(WidgetTester tester) async {
    final boton = find.widgetWithText(FilledButton, 'Crear cuenta');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'checks the DNI and the repeated password before contacting the server',
    (tester) async {
      var pedidos = 0;
      final sesion = sesionDePrueba((_) async {
        pedidos++;
        return respuestaJson({}, 200);
      });
      await mostrarRegistro(tester, sesion);

      await completarFormulario(
        tester,
        dni: '123',
        repetirPassword: 'otra-cosa',
      );
      await tocarCrearCuenta(tester);

      expect(find.text('El DNI debe tener 7 u 8 números.'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(pedidos, 0);
    },
  );

  testWidgets('shows under the DNI field that it is already registered', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      (_) async => respuestaJson({
        'message': 'Ya existe una cuenta con ese DNI.',
        'errors': {
          'dni': ['Ya existe una cuenta con ese DNI.'],
        },
      }, 422),
    );
    await mostrarRegistro(tester, sesion);

    await completarFormulario(tester);
    await tocarCrearCuenta(tester);

    expect(find.text('Ya existe una cuenta con ese DNI.'), findsOneWidget);
    expect(find.text('Revisá los datos marcados.'), findsOneWidget);
  });

  testWidgets(
    'sends the DNI without dots and closes after creating the account',
    (tester) async {
      late Map<String, dynamic> enviado;
      final sesion = sesionDePrueba((pedido) async {
        enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
        return respuestaJson({'token': '1|abc', 'usuario': usuarioJson()}, 201);
      });
      await mostrarRegistro(tester, sesion);

      await completarFormulario(tester, dni: '30.111.222');
      await tocarCrearCuenta(tester);

      expect(enviado['dni'], '30111222');
      expect(sesion.estado, EstadoSesion.conSesion);
      expect(find.text('Pantalla anterior'), findsOneWidget);
    },
  );
}
