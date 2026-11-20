import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:mobile/main.dart';
import 'package:mobile/pantallas/detalle_reclamo_vecino_page.dart';

import '../helpers.dart';

Map<String, dynamic> detalle(
  Map<String, dynamic> reclamo, {
  bool propio = false,
}) => {
  ...reclamo,
  'puede_editar': propio,
  'puede_eliminar': propio,
  'puede_votar': !propio,
};

void main() {
  testWidgets(
    'mis reclamos abre directamente detalle propio y de otro vecino',
    (tester) async {
      var votos = 1;
      final propio = {
        ...reclamoJson(id: 1, titulo: 'Mi reclamo'),
        'usuario_id': 7,
      };
      Map<String, dynamic> ajeno() => {
        ...reclamoJson(id: 2, titulo: 'Otro reclamo', confirmaciones: votos),
        'usuario_id': 8,
        'mi_voto': votos == 1 ? 'confirma' : null,
        'descripcion': 'Descripción conservada',
      };
      final sesion = sesionDePrueba(
        servidorConRutas({
          '/api/usuario': (_) async =>
              respuestaJson({'data': usuarioJson()}, 200),
          '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
          '/api/reclamos': (_) async => respuestaJson({
            'data': [propio, ajeno()],
          }, 200),
          '/api/reclamos/1': (_) async =>
              respuestaJson({'data': detalle(propio, propio: true)}, 200),
          '/api/reclamos/2': (_) async =>
              respuestaJson({'data': detalle(ajeno())}, 200),
          '/api/reclamos/2/votar': (_) async {
            votos = 0;
            return respuestaJson({'confirmaciones': 0, 'desmentidas': 0}, 200);
          },
        }),
        almacen: AlmacenTokenEnMemoria('token'),
      );
      await sesion.restaurar();
      await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reclamos')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi reclamo'));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleReclamoVecinoPage), findsOneWidget);
      expect(find.text('Tu reclamo'), findsOneWidget);
      expect(
        tester
            .widget<FButton>(find.widgetWithText(FButton, 'Confirmar (0)'))
            .onPress,
        isNull,
      );
      Navigator.of(tester.element(find.text('Tu reclamo'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suscritos / Votados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otro reclamo'));
      await tester.pumpAndSettle();
      expect(find.text('Descripción conservada'), findsOneWidget);
      await tester.tap(find.text('Confirmar (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar (0)'), findsOneWidget);
      expect(find.text('Quitaste tu voto.'), findsOneWidget);
    },
  );

  testWidgets('el detalle largo permite desplazarse hasta las acciones', (
    tester,
  ) async {
    final reclamo = {
      ...reclamoJson(id: 4, titulo: 'Detalle largo'),
      'usuario_id': 7,
      'descripcion': List.filled(100, 'Descripción extensa.').join(' '),
    };
    final sesion = sesionDePrueba(
      servidorConRutas({
        '/api/usuario': (_) async =>
            respuestaJson({'data': usuarioJson()}, 200),
        '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
        '/api/reclamos': (_) async => respuestaJson({
          'data': [reclamo],
        }, 200),
        '/api/reclamos/4': (_) async =>
            respuestaJson({'data': detalle(reclamo, propio: true)}, 200),
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
            of: find.byType(DetalleReclamoVecinoPage),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    expect(find.text('Confirmar (0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desde el mapa el resumen abre el detalle sin paneles apilados', (
    tester,
  ) async {
    final reclamo = {
      ...reclamoJson(id: 3, titulo: 'Desde el mapa', confirmaciones: 2),
      'usuario_id': 8,
    };
    final sesion = sesionDePrueba(
      servidorConRutas({
        '/api/usuario': (_) async =>
            respuestaJson({'data': usuarioJson()}, 200),
        '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
        '/api/reclamos': (_) async => respuestaJson({
          'data': [reclamo],
        }, 200),
        '/api/reclamos/3': (_) async =>
            respuestaJson({'data': detalle(reclamo)}, 200),
      }),
      almacen: AlmacenTokenEnMemoria('token'),
    );
    await sesion.restaurar();
    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pin-3')));
    await tester.pumpAndSettle();
    expect(find.text('Desde el mapa'), findsOneWidget);
    expect(find.text('Confirmar (2)'), findsNothing);
    await tester.tap(find.text('Ver reclamo completo'));
    await tester.pumpAndSettle();
    expect(find.byType(DetalleReclamoVecinoPage), findsOneWidget);
    expect(find.text('Ver reclamo completo'), findsNothing);
    expect(find.text('Confirmar (2)'), findsOneWidget);
    Navigator.of(tester.element(find.text('Confirmar (2)'))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pin-3')), findsOneWidget);
  });

  for (final fallaInicial in [false, true]) {
    testWidgets(
      'lista de votos ${fallaInicial ? 'permite reintentar' : 'agrupa y permite cerrar'}',
      (tester) async {
        var intentos = 0;
        final reclamo = {
          ...reclamoJson(id: 3, titulo: 'Con votos', confirmaciones: 20),
          'usuario_id': 8,
        };
        final sesion = sesionDePrueba(
          servidorConRutas({
            '/api/usuario': (_) async =>
                respuestaJson({'data': usuarioJson()}, 200),
            '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
            '/api/reclamos': (_) async => respuestaJson({
              'data': [reclamo],
            }, 200),
            '/api/reclamos/3': (_) async =>
                respuestaJson({'data': detalle(reclamo)}, 200),
            '/api/reclamos/3/votos': (_) async {
              intentos++;
              if (fallaInicial && intentos == 1) {
                return respuestaJson({
                  'message': 'Error al cargar votos.',
                }, 500);
              }
              return respuestaJson({
                'data': [
                  for (var i = 0; i < 20; i++)
                    {'usuario': 'Vecino $i', 'valor': 'confirma'},
                  {'usuario': 'Otra vecina', 'valor': 'desmiente'},
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
        await tester.tap(find.text('Ver reclamo completo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver lista de votantes'));
        await tester.pumpAndSettle();
        expect(find.text('Votos del reclamo'), findsOneWidget);
        if (fallaInicial) {
          await tester.tap(find.text('Reintentar'));
          await tester.pumpAndSettle();
          expect(intentos, 2);
        }
        expect(find.text('21 votos'), findsOneWidget);
        expect(find.text('Confirmaciones · 20'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Desmentidas · 1'),
          300,
          scrollable: find
              .ancestor(
                of: find.text('Confirmaciones · 20'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Otra vecina'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Cerrar panel'));
        await tester.pumpAndSettle();
        expect(find.text('Votos del reclamo'), findsNothing);
      },
    );
  }
}
