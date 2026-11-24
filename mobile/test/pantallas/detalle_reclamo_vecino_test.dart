import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modelos/reclamo_mapa.dart';
import 'package:forui/forui.dart';
import 'package:mobile/pantallas/detalle_reclamo_vecino_page.dart';

import '../helpers.dart';

void main() {
  for (final propio in [true, false]) {
    testWidgets('detalle ${propio ? 'propio' : 'ajeno'} aplica permisos del servidor', (tester) async {
      final inicial = {...reclamoJson(), 'usuario_id': propio ? 7 : 8};
      var fallo = false;
      final sesion = sesionDePrueba((request) async {
        if (request.url.path == '/api/usuario') return respuestaJson({'data': usuarioJson()}, 200);
        if (request.url.path == '/api/reclamos/1') {
          if (fallo) return respuestaJson({'message': 'Ya no disponible'}, 404);
          return respuestaJson({'data': {...inicial, 'puede_editar': propio, 'puede_eliminar': propio, 'puede_votar': !propio}}, 200);
        }
        return respuestaJson({'message': 'No encontrado'}, 404);
      }, almacen: AlmacenTokenEnMemoria('token'));
      await sesion.restaurar();
      await tester.pumpWidget(MaterialApp(home: DetalleReclamoVecinoPage(reclamo: ReclamoMapa.fromJson(inicial), sesion: sesion)));
      await tester.pumpAndSettle();
      expect(find.text('Reclamo #1'), findsOneWidget);
      expect(find.text('Editar reclamo'), propio ? findsOneWidget : findsNothing);
      if (propio) {
        await tester.scrollUntilVisible(find.text('Dar de baja'), 200, scrollable: find.byType(Scrollable).last);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Dar de baja'), findsOneWidget);
      } else {
        expect(find.text('Dar de baja'), findsNothing);
      }
      expect(find.text('No podés votar tu propio reclamo.'), propio ? findsOneWidget : findsNothing);
      if (!propio) {
        fallo = true;
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('Este reclamo ya no está disponible.'), findsOneWidget);
        final boton = tester.widget<FButton>(find.ancestor(of: find.text('Confirmar (0)'), matching: find.byType(FButton)).first);
        expect(boton.onPress, isNull);
      }
    });
  }

  testWidgets('conserva el borrador al cambiar de pestaña', (tester) async {
    final inicial = {...reclamoJson(), 'usuario_id': 8};
    final sesion = sesionDePrueba((request) async {
      if (request.url.path == '/api/usuario') return respuestaJson({'data': usuarioJson()}, 200);
      if (request.url.path == '/api/reclamos/1') return respuestaJson({'data': {...inicial, 'puede_editar': false, 'puede_eliminar': false, 'puede_votar': true}}, 200);
      if (request.url.path.endsWith('/comentarios')) return respuestaJson({'data': [], 'meta': {'disponibles': 3, 'motivo_bloqueo': null, 'puede_modificar_propios': true}}, 200);
      if (request.url.path.endsWith('/historial')) return respuestaJson({'data': []}, 200);
      return respuestaJson({}, 404);
    }, almacen: AlmacenTokenEnMemoria('token'));
    await sesion.restaurar();
    await tester.pumpWidget(MaterialApp(home: DetalleReclamoVecinoPage(reclamo: ReclamoMapa.fromJson(inicial), sesion: sesion)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comentarios'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Un borrador');
    await tester.tap(find.text('Seguimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comentarios'));
    await tester.pumpAndSettle();
    expect(find.text('Un borrador'), findsOneWidget);
  });
}
