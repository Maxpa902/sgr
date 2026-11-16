import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:mobile/pantallas/crear_cuenta_interna_page.dart';
import 'package:mobile/pantallas/usuarios_page.dart';
import 'package:mobile/sesion/sesion.dart';
import 'package:mobile/tema/colores.dart';
import 'package:mobile/tema/tema_app.dart';

import '../helpers.dart';

void main() {
  testWidgets('la ruta de creación conserva el tema azul de administración', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      (_) async => respuestaJson({'data': []}, 200),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: TemaApp(child: UsuariosPage(sesion: sesion)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    final contexto = tester.element(find.byType(CrearCuentaInternaPage));
    expect(contexto.theme.colors.primary, ColoresApp.principal);
  });

  /// Abre el registro encima de otra pantalla, como pasa en la app real.
  Future<void> mostrarRegistro(WidgetTester tester, Sesion sesion) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Pantalla anterior'))),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                TemaApp(child: CrearCuentaInternaPage(sesion: sesion)),
          ),
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
    final indices = [1, 2, 3, 4, 6, 7];
    for (final (index, valor) in campos.values.indexed) {
      await tester.enterText(
        find.byType(EditableText).at(indices[index]),
        valor,
      );
    }
  }

  Future<void> tocarCrearCuenta(WidgetTester tester) async {
    final boton = find.widgetWithText(FButton, 'Crear cuenta');
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
        expect(pedido.url.path, '/api/usuarios');
        return respuestaJson({}, 201);
      });
      await mostrarRegistro(tester, sesion);

      await completarFormulario(tester, dni: '30.111.222');
      await tocarCrearCuenta(tester);

      expect(enviado['dni'], '30111222');
      expect(enviado['rol'], 'empleado');
      expect(sesion.estado, EstadoSesion.cargando);
      expect(find.text('Pantalla anterior'), findsOneWidget);
    },
  );
}
