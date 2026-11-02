import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/pantallas/detalle_reclamo_admin_page.dart';

import '../helpers.dart';

void main() {
  testWidgets('permite actualizar desde la pantalla de error inicial', (
    tester,
  ) async {
    var consultas = 0;
    final sesion = sesionDePrueba((request) async {
      if (request.url.path == '/api/admin/reclamos/28') {
        consultas++;
        return consultas == 1
            ? respuestaJson({'message': 'Sin conexión'}, 500)
            : respuestaJson({'data': _detalle()}, 200);
      }
      return respuestaJson({}, 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: DetalleReclamoAdminPage(
          sesion: sesion,
          reclamoId: 28,
          mostrarMapaBase: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    final lista = find.byType(ListView).first;
    final gesto = await tester.startGesture(
      tester.getTopLeft(lista) + const Offset(40, 20),
    );
    await gesto.moveBy(const Offset(0, 400));
    await gesto.up();
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(find.text('Alumbrado'), findsOneWidget);
  });

  testWidgets(
    'deslizar actualiza el detalle sin ocultarlo y avisa al listado',
    (tester) async {
      var consultas = 0;
      var cambios = 0;
      final respuesta = Completer<http.Response>();
      final sesion = sesionDePrueba((request) async {
        if (request.url.path == '/api/admin/reclamos/28') {
          consultas++;
          if (consultas == 1) return respuestaJson({'data': _detalle()}, 200);
          return respuesta.future;
        }
        return respuestaJson({}, 404);
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              FTheme(data: FTheme.neutral.light.touch, child: child!),
          home: DetalleReclamoAdminPage(
            sesion: sesion,
            reclamoId: 28,
            mostrarMapaBase: false,
            alCambiar: () => cambios++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lista = find.byType(ListView).first;
      final gesto = await tester.startGesture(
        tester.getTopLeft(lista) + const Offset(40, 20),
      );
      await gesto.moveBy(const Offset(0, 400));
      await gesto.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(consultas, 2);
      expect(find.text('Alumbrado'), findsOneWidget);
      expect(cambios, 0);
      respuesta.complete(
        respuestaJson({
          'data': _detalle()..['titulo'] = 'Título actualizado',
        }, 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Título actualizado'), findsOneWidget);
      expect(cambios, 1);
    },
  );

  testWidgets('si falla la actualización mantiene el detalle y muestra error', (
    tester,
  ) async {
    var consultas = 0;
    var cambios = 0;
    final sesion = sesionDePrueba((request) async {
      if (request.url.path == '/api/admin/reclamos/28') {
        consultas++;
        return consultas == 1
            ? respuestaJson({'data': _detalle()}, 200)
            : respuestaJson({'message': 'Error al actualizar'}, 500);
      }
      return respuestaJson({}, 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: DetalleReclamoAdminPage(
          sesion: sesion,
          reclamoId: 28,
          mostrarMapaBase: false,
          alCambiar: () => cambios++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lista = find.byType(ListView).first;
    final gesto = await tester.startGesture(
      tester.getTopLeft(lista) + const Offset(40, 20),
    );
    await gesto.moveBy(const Offset(0, 400));
    await gesto.up();
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(find.text('Alumbrado'), findsOneWidget);
    expect(find.byType(FDialog), findsOneWidget);
    expect(cambios, 0);
  });

  testWidgets('cerrar los paneles sin cambios no recarga el reclamo', (
    tester,
  ) async {
    var consultas = 0;
    var cambios = 0;
    final sesion = sesionDePrueba((request) async {
      if (request.url.path == '/api/admin/reclamos/28') {
        consultas++;
        return respuestaJson({'data': _detalle()}, 200);
      }
      if (request.url.path == '/api/usuarios') {
        return respuestaJson({
          'data': [],
          'meta': {'total': 0},
        }, 200);
      }
      return respuestaJson({}, 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: DetalleReclamoAdminPage(
          sesion: sesion,
          reclamoId: 28,
          mostrarMapaBase: false,
          alCambiar: () => cambios++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(consultas, 1);

    await tester.tap(find.text('Asignar'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('superficie-panel-reclamo')),
          )
          .color
          .a,
      1.0,
    );
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(consultas, 1);

    await tester.tap(find.text('Rechazar reclamo'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('superficie-panel-reclamo')),
          )
          .color
          .a,
      1.0,
    );
    await tester.enterText(find.byType(EditableText), 'No corresponde');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.byType(FDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FDialog),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoracion = widget.decoration;
          return decoracion is ShapeDecoration && decoracion.color?.a == 1.0;
        }),
      ),
      findsWidgets,
    );
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(consultas, 1);
    expect(cambios, 0);
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver historial completo'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('superficie-panel-reclamo')),
          )
          .color
          .a,
      1.0,
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
    'una asignación exitosa actualiza detalle y notifica al listado',
    (tester) async {
      var consultas = 0;
      var cambios = 0;
      var asignado = false;
      final sesion = sesionDePrueba((request) async {
        if (request.url.path == '/api/admin/reclamos/28') {
          consultas++;
          return respuestaJson({'data': _detalle(asignado: asignado)}, 200);
        }
        if (request.url.path == '/api/usuarios') {
          return respuestaJson({
            'data': [
              {
                'id': 9,
                'nombre': 'Luis',
                'apellido': 'Paz',
                'email': 'luis@example.com',
                'rol': 'empleado',
                'activo': true,
              },
            ],
            'meta': {'total': 1},
          }, 200);
        }
        if (request.url.path == '/api/reclamos/28/asignacion' &&
            request.method == 'POST') {
          asignado = true;
          return respuestaJson({'data': {}}, 200);
        }
        return respuestaJson({}, 404);
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              FTheme(data: FTheme.neutral.light.touch, child: child!),
          home: DetalleReclamoAdminPage(
            sesion: sesion,
            reclamoId: 28,
            mostrarMapaBase: false,
            alCambiar: () => cambios++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asignar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Luis Paz'));
      await tester.pumpAndSettle();
      expect(consultas, 2);
      expect(cambios, 1);
      expect(find.text('Luis Paz'), findsOneWidget);
    },
  );

  testWidgets('muestra historial real y la última desasignación', (
    tester,
  ) async {
    final detalle = _detalle(asignado: true)
      ..addAll({
        'asignado_por': {'id': 4, 'nombre': 'Ana', 'apellido': 'Pérez'},
        'asignado_en': '2026-10-24T12:30:00Z',
        'ultima_desasignacion': {
          'responsable': {'id': 8, 'nombre': 'Juan', 'apellido': 'López'},
          'autor': {'id': 4, 'nombre': 'Ana', 'apellido': 'Pérez'},
          'creado_en': '2026-10-23T12:30:00Z',
        },
        'historial': [
          {
            'id': 1,
            'estado': 'pendiente',
            'autor': {'id': 4, 'nombre': 'Ana', 'apellido': 'Pérez'},
            'observacion': null,
            'visibilidad': 'publica',
            'creado_en': '2026-10-22T12:30:00Z',
          },
          {
            'id': 2,
            'estado': 'en_proceso',
            'autor': {'id': 9, 'nombre': 'Luis', 'apellido': 'Paz'},
            'observacion': 'Cuadrilla en camino',
            'visibilidad': 'interna',
            'creado_en': '2026-10-25T12:30:00Z',
          },
        ],
      });
    final sesion = sesionDePrueba((request) async {
      return request.url.path == '/api/admin/reclamos/28'
          ? respuestaJson({'data': detalle}, 200)
          : respuestaJson({}, 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: DetalleReclamoAdminPage(
          sesion: sesion,
          reclamoId: 28,
          mostrarMapaBase: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Luis Paz'), findsOneWidget);
    expect(find.textContaining('por Ana Pérez'), findsWidgets);
    expect(
      find.textContaining('Último responsable desasignado: Juan López'),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('En proceso'), findsOneWidget);
    expect(find.text('Interna'), findsOneWidget);
    expect(find.text('Cuadrilla en camino'), findsOneWidget);
    expect(find.text('Reclamo recibido'), findsOneWidget);
    await tester.tap(find.text('Ver historial completo'));
    await tester.pumpAndSettle();
    expect(find.text('Historial del reclamo'), findsOneWidget);
    expect(find.text('Cuadrilla en camino'), findsWidgets);
  });
}

Map<String, dynamic> _detalle({bool asignado = false}) => {
  'id': 28,
  'titulo': 'Alumbrado',
  'descripcion': 'Lámpara apagada',
  'latitud': -45.8,
  'longitud': -67.5,
  'tipo': tipoJson(),
  'estado': 'pendiente',
  'creador': 'Ana Pérez',
  'email_creador': 'ana@example.com',
  'creado_en': '2026-10-22T12:30:00Z',
  'fotos': <String>[],
  'responsable': asignado
      ? {'id': 9, 'nombre': 'Luis', 'apellido': 'Paz'}
      : null,
};
