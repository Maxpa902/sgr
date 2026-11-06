import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

import '../helpers.dart';

void main() {
  testWidgets('muestra reclamos creados y votados y conserva el detalle', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      servidorConRutas({
        '/api/usuario': (_) async =>
            respuestaJson({'data': usuarioJson()}, 200),
        '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
        '/api/reclamos': (_) async => respuestaJson({
          'data': [
            {...reclamoJson(id: 1, titulo: 'Mi reclamo'), 'usuario_id': 7},
            {
              ...reclamoJson(id: 2, titulo: 'Otro reclamo', confirmaciones: 1),
              'usuario_id': 8,
              'mi_voto': 'confirma',
              'descripcion': 'Descripción conservada',
            },
          ],
        }, 200),
        '/api/reclamos/2/votar': (_) async => respuestaJson({
          'confirmaciones': 0,
          'desmentidas': 0,
          'message': 'Voto registrado correctamente',
        }, 200),
      }),
      almacen: AlmacenTokenEnMemoria('token'),
    );
    await sesion.restaurar();
    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reclamos')));
    await tester.pumpAndSettle();

    expect(find.text('Mi reclamo'), findsOneWidget);
    await tester.tap(find.text('Mi reclamo'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    expect(find.text('Confirmar (0)'), findsOneWidget);
    final botonPropio = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Confirmar (0)'),
    );
    expect(botonPropio.onPressed, isNull);
    Navigator.of(tester.element(find.text('Confirmar (0)'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suscritos / Votados'));
    await tester.pumpAndSettle();
    expect(find.text('Otro reclamo'), findsOneWidget);
    expect(find.text('Confirmaste'), findsOneWidget);
    await tester.tap(find.text('Otro reclamo'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    expect(find.text('Descripción conservada'), findsOneWidget);
    await tester.tap(find.text('Confirmar (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Se quitó tu voto correctamente'), findsOneWidget);
    expect(find.text('Confirmar (0)'), findsOneWidget);
  });
  testWidgets('el detalle largo se puede desplazar hasta las acciones', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      servidorConRutas({
        '/api/usuario': (_) async =>
            respuestaJson({'data': usuarioJson()}, 200),
        '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
        '/api/reclamos': (_) async => respuestaJson({
          'data': [
            {
              ...reclamoJson(id: 4, titulo: 'Detalle largo'),
              'usuario_id': 7,
              'descripcion': List.filled(100, 'Descripción extensa.').join(' '),
            },
          ],
        }, 200),
      }),
      almacen: AlmacenTokenEnMemoria('token'),
    );
    await sesion.restaurar();
    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reclamos')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detalle largo'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Confirmar (0)'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Confirmar (0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('el detalle compartido sigue abriéndose desde el mapa', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      servidorConRutas({
        '/api/usuario': (_) async =>
            respuestaJson({'data': usuarioJson()}, 200),
        '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
        '/api/reclamos': (_) async => respuestaJson({
          'data': [
            {
              ...reclamoJson(id: 3, titulo: 'Desde el mapa', confirmaciones: 2),
              'usuario_id': 8,
            },
          ],
        }, 200),
      }),
      almacen: AlmacenTokenEnMemoria('token'),
    );
    await sesion.restaurar();
    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pin-3')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    expect(find.text('Desde el mapa'), findsOneWidget);
    expect(find.text('Confirmar (2)'), findsOneWidget);
    expect(find.text('Desmentir (0)'), findsOneWidget);
  });
  testWidgets('lista de votos agrupa, permite desplazar y cerrar', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      servidorConRutas({
        '/api/usuario': (_) async =>
            respuestaJson({'data': usuarioJson()}, 200),
        '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
        '/api/reclamos': (_) async => respuestaJson({
          'data': [
            {
              ...reclamoJson(id: 3, titulo: 'Con votos', confirmaciones: 20),
              'usuario_id': 8,
            },
          ],
        }, 200),
        '/api/reclamos/3/votos': (_) async => respuestaJson({
          'data': [
            for (var i = 0; i < 20; i++)
              {'usuario': 'Vecino $i', 'valor': 'confirma'},
            {'usuario': 'Otra vecina', 'valor': 'desmiente'},
          ],
        }, 200),
      }),
      almacen: AlmacenTokenEnMemoria('token'),
    );
    await sesion.restaurar();
    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pin-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver lista de votantes'));
    await tester.pumpAndSettle();
    expect(find.text('Votos del reclamo'), findsOneWidget);
    expect(find.text('21 votos'), findsOneWidget);
    expect(find.text('Confirmaciones · 20'), findsOneWidget);
    expect(find.text('Vecino 0'), findsOneWidget);
    expect(find.text('Confirmó el reclamo'), findsNothing);
    final panel = find.byType(BottomSheet).last;
    expect(
      tester.getSize(panel).height,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    await tester.scrollUntilVisible(
      find.text('Desmentidas · 1'),
      300,
      scrollable: find
          .descendant(of: panel, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Otra vecina'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Votos del reclamo'), findsNothing);
  });

  testWidgets('lista de votos informa error y permite reintentar', (
    tester,
  ) async {
    var intentos = 0;
    final sesion = sesionDePrueba(
      servidorConRutas({
        '/api/usuario': (_) async =>
            respuestaJson({'data': usuarioJson()}, 200),
        '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
        '/api/reclamos': (_) async => respuestaJson({
          'data': [
            {
              ...reclamoJson(id: 3, titulo: 'Con votos', confirmaciones: 1),
              'usuario_id': 8,
            },
          ],
        }, 200),
        '/api/reclamos/3/votos': (_) async {
          intentos++;
          if (intentos == 1) {
            return respuestaJson({'message': 'Error al cargar votos.'}, 500);
          }
          return respuestaJson({
            'data': [
              {'usuario': 'Vecina', 'valor': 'confirma'},
            ],
          }, 200);
        },
      }),
      almacen: AlmacenTokenEnMemoria('token'),
    );
    await sesion.restaurar();
    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pin-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver lista de votantes'));
    await tester.pumpAndSettle();
    expect(find.text('Ocurrió un error en el servidor. Intentá de nuevo más tarde.'), findsOneWidget);
    expect(
      find.text('Aún no hay votos registrados para este reclamo.'),
      findsNothing,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Vecina'), findsOneWidget);
    expect(find.text('1 voto'), findsOneWidget);
    expect(intentos, 2);
  });
}
