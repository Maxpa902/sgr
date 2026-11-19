import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/modelos/usuario.dart';
import 'package:mobile/pantallas/sanciones_vecino_page.dart';
import 'package:mobile/sesion/sesion.dart';
import 'package:mobile/tema/tema_app.dart';

import '../helpers.dart';

// Los tests que escriben en un FTextField van con `semanticsEnabled: false`:
// con Flutter 3.47 y Forui 0.25, escribir en el campo dispara la aserción
// interna 'node.isMergedIntoParent' (también rompe tests de login y cuentas).
// Se puede quitar cuando se actualice Forui o Flutter y deje de pasar.
void main() {
  final vecino = Usuario.fromJson(usuarioJson());
  const rutaSanciones = '/api/admin/usuarios/7/sanciones';
  const rutaRevocar = '/api/admin/sanciones/3/revocar';

  /// Lo que devuelve el server para una sanción; `revocada` cambia su estado.
  Map<String, dynamic> sancionJson({required bool revocada}) => {
    'id': 3,
    'reclamo': {'id': 12, 'titulo': 'Pozo en la vereda'},
    'activa': !revocada,
    'creada_en': '2026-11-18T12:00:00+00:00',
    'termina_en': '2026-12-18T12:00:00+00:00',
    'revocada_en': revocada ? '2026-11-19T12:00:00+00:00' : null,
    'revocada_por': revocada
        ? {'id': 1, 'nombre': 'Laura', 'apellido': 'Gómez'}
        : null,
    'motivo_revocacion': revocada ? 'El pozo existía' : null,
  };

  Map<String, dynamic> respuestaSanciones({required bool revocada}) => {
    'data': [sancionJson(revocada: revocada)],
    'usuario': {
      'id': 7,
      'suspendido_hasta': revocada ? null : '2099-12-18T12:00:00+00:00',
    },
  };

  Future<void> mostrarPantalla(WidgetTester tester, Sesion sesion) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: TemaApp(
          child: SancionesVecinoPage(sesion: sesion, vecino: vecino),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirPanelDeRevocacion(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FButton, 'Revocar sanción'));
    await tester.pumpAndSettle();
  }

  testWidgets('revoca una sanción activa con su motivo y recarga la lista', (
    tester,
  ) async {
    var revocada = false;
    Map<String, dynamic>? cuerpoEnviado;
    final sesion = sesionDePrueba(
      servidorConRutas({
        rutaSanciones: (_) async =>
            respuestaJson(respuestaSanciones(revocada: revocada), 200),
        rutaRevocar: (pedido) async {
          cuerpoEnviado = jsonDecode(pedido.body) as Map<String, dynamic>;
          revocada = true;
          return respuestaJson({'data': sancionJson(revocada: true)}, 200);
        },
      }),
    );
    await mostrarPantalla(tester, sesion);
    expect(find.textContaining('Suspendido hasta el'), findsOneWidget);
    expect(find.text('Pozo en la vereda'), findsOneWidget);
    await abrirPanelDeRevocacion(tester);

    await tester.enterText(find.byType(EditableText), '  El pozo existía  ');
    await tester.tap(find.widgetWithText(FButton, 'Confirmar revocación'));
    await tester.pumpAndSettle();

    expect(cuerpoEnviado, {'motivo': 'El pozo existía'});
    expect(find.text('No está suspendido.'), findsOneWidget);
    expect(find.textContaining('Revocada el'), findsOneWidget);
    expect(find.text('Laura Gómez: El pozo existía'), findsOneWidget);
    expect(find.widgetWithText(FButton, 'Revocar sanción'), findsNothing);
  }, semanticsEnabled: false);

  testWidgets('no envía la revocación sin motivo', (tester) async {
    var pedidosDeRevocacion = 0;
    final sesion = sesionDePrueba(
      servidorConRutas({
        rutaSanciones: (_) async =>
            respuestaJson(respuestaSanciones(revocada: false), 200),
        rutaRevocar: (_) async {
          pedidosDeRevocacion++;
          return http.Response('', 500);
        },
      }),
    );
    await mostrarPantalla(tester, sesion);
    await abrirPanelDeRevocacion(tester);

    await tester.tap(find.widgetWithText(FButton, 'Confirmar revocación'));
    await tester.pumpAndSettle();

    expect(find.text('Escribí el motivo de la revocación.'), findsOneWidget);
    expect(pedidosDeRevocacion, 0);
  });

  testWidgets('muestra el error del server y deja el panel abierto', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      servidorConRutas({
        rutaSanciones: (_) async =>
            respuestaJson(respuestaSanciones(revocada: false), 200),
        rutaRevocar: (_) async =>
            respuestaJson({'message': 'La sanción ya fue revocada.'}, 409),
      }),
    );
    await mostrarPantalla(tester, sesion);
    await abrirPanelDeRevocacion(tester);

    await tester.enterText(find.byType(EditableText), 'El pozo existía');
    await tester.tap(find.widgetWithText(FButton, 'Confirmar revocación'));
    await tester.pumpAndSettle();

    expect(find.text('La sanción ya fue revocada.'), findsOneWidget);
    expect(
      find.widgetWithText(FButton, 'Confirmar revocación'),
      findsOneWidget,
    );
  }, semanticsEnabled: false);
}
