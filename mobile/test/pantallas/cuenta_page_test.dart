import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pantallas/operario_page.dart';
import 'package:mobile/pantallas/mapa_page.dart';
import 'package:mobile/pantallas/panel_interno_page.dart';
import 'package:mobile/sesion/sesion.dart';

import '../helpers.dart';

void main() {
  for (final rol in ['ciudadano', 'empleado', 'admin']) {
    testWidgets('$rol puede consultar su cuenta y cerrar sesión', (
      tester,
    ) async {
      final almacen = AlmacenTokenEnMemoria('token');
      var cerroSesion = false;
      final sesion = sesionDePrueba((request) async {
        if (request.url.path == '/api/usuario') {
          return respuestaJson({
            'data': {...usuarioJson(), 'rol': rol, 'telefono': '2971234567'},
          }, 200);
        }
        if (request.url.path == '/api/logout') {
          cerroSesion = true;
          return respuestaJson({}, 200);
        }
        if (request.url.path == '/api/trabajo/reclamos') {
          return respuestaJson({
            'data': [],
            'meta': {'next_cursor': null},
          }, 200);
        }
        if (request.url.path == '/api/reclamos' ||
            request.url.path == '/api/tipos-reclamo') {
          return respuestaJson({'data': []}, 200);
        }
        return respuestaJson({}, 404);
      }, almacen: almacen);
      await sesion.restaurar();
      await tester.pumpWidget(
        MaterialApp(
          home: switch (rol) {
            'admin' => PanelInternoPage(sesion: sesion),
            'empleado' => OperarioPage(sesion: sesion, mostrarMapaBase: false),
            _ => PantallaPrincipal(sesion: sesion, mostrarMapaBase: false),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.account_circle_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('ana@example.com'), findsOneWidget);
      expect(
        find.text(switch (rol) {
          'admin' => 'Administrador',
          'empleado' => 'Operario',
          _ => 'Vecino',
        }),
        findsOneWidget,
      );
      expect(find.text('2971234567'), findsOneWidget);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(cerroSesion, isTrue);
      expect(sesion.estado, EstadoSesion.sinSesion);
      expect(almacen.token, isNull);
    });
  }
}
