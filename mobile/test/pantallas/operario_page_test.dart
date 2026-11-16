import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:forui/forui.dart';
import 'package:mobile/pantallas/operario_page.dart';

import '../helpers.dart';

void main() {
  testWidgets('lista larga se adapta al ancho de un teléfono pequeño', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sesion = sesionDePrueba((request) async {
      if (request.url.path == '/api/trabajo/reclamos') {
        return respuestaJson({
          'data': [
            _lista('en_proceso')
              ..['titulo'] =
                  'Corte de electricidad prolongado en todo el barrio'
              ..['direccion'] =
                  'Presidente Marcelo Ortiz Sergio Chávez 1234, Comodoro Rivadavia',
          ],
          'meta': {'next_cursor': null},
        }, 200);
      }
      return respuestaJson({}, 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: OperarioPage(sesion: sesion, mostrarMapaBase: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trabajo'), findsWidgets);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.text('Prueba'), findsNothing);
    expect(
      find.text('Corte de electricidad prolongado en todo el barrio'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el operario toma un reclamo y comienza el trabajo', (
    tester,
  ) async {
    var asignado = false;
    var estado = 'pendiente';
    Completer<void>? esperarDetalle;
    final paginaDemorada = Completer<void>();
    final sesion = sesionDePrueba((request) async {
      if (request.url.path == '/api/usuario') {
        return respuestaJson({
          'data': {...usuarioJson(), 'rol': 'empleado'},
        }, 200);
      }
      if (request.url.path == '/api/trabajo/reclamos') {
        final vista = request.url.queryParameters['vista'];
        if (vista == 'disponibles' && request.url.queryParameters['cursor'] == 'tarde') {
          await paginaDemorada.future;
          return respuestaJson({
            'data': [_lista('pendiente')],
            'meta': {'next_cursor': null},
          }, 200);
        }
        final incluir = vista == 'disponibles' ? !asignado : asignado;
        return respuestaJson({
          'data': incluir ? [_lista(estado)] : [],
          'meta': {
            'total': incluir ? 1 : 0,
            'next_cursor': vista == 'disponibles' && incluir ? 'tarde' : null,
          },
        }, 200);
      }
      if (request.url.path == '/api/trabajo/reclamos/28') {
        await esperarDetalle?.future;
        return respuestaJson({'data': _detalle(estado, asignado)}, 200);
      }
      if (request.url.path == '/api/reclamos/28/asignacion') {
        expect(jsonDecode(request.body), {'responsable_id': 7});
        asignado = true;
        return respuestaJson({'data': {}}, 200);
      }
      if (request.url.path == '/api/reclamos/28/comenzar') {
        estado = 'en_proceso';
        return respuestaJson({'data': {}}, 200);
      }
      return respuestaJson({}, 404);
    }, almacen: AlmacenTokenEnMemoria('token'));
    await sesion.restaurar();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: OperarioPage(sesion: sesion, mostrarMapaBase: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No tenés reclamos asignados'), findsOneWidget);
    await tester.tap(find.text('Disponibles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cable caído'));
    await tester.pumpAndSettle();
    esperarDetalle = Completer<void>();
    await tester.tap(find.text('Tomar reclamo'));
    await tester.pump();
    expect(find.text('Cable caído'), findsOneWidget);
    expect(find.text('Reclamo asignado'), findsOneWidget);
    esperarDetalle!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Comenzar trabajo'), findsOneWidget);
    await tester.tap(find.text('Comenzar trabajo'));
    await tester.pump();
    expect(find.text('Trabajo iniciado'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('En proceso'), findsOneWidget);
    expect(find.text('Comenzar trabajo'), findsNothing);
    expect(
      find.text('Finalizar trabajo'),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    paginaDemorada.complete();
    await tester.pumpAndSettle();
    expect(find.text('No hay reclamos disponibles'), findsOneWidget);
    await tester.tap(find.text('Asignados a mí'));
    await tester.pumpAndSettle();
    expect(find.text('Cable caído'), findsOneWidget);
  });

  testWidgets('el mapa informa el error de teselas sin ocultar los reclamos', (
    tester,
  ) async {
    final sesion = sesionDePrueba((request) async {
      if (request.url.path == '/api/trabajo/reclamos') {
        return respuestaJson({
          'data': [_lista('pendiente')],
          'meta': {'next_cursor': null},
        }, 200);
      }
      return respuestaJson({}, 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: OperarioPage(sesion: sesion),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    layer.errorTileCallback!(_TileFalso(), Exception('falló'), null);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudieron cargar algunas partes del mapa.'),
      findsOneWidget,
    );
    expect(find.text('2 reclamos asignados y disponibles'), findsOneWidget);
  });

  testWidgets('el mapa consulta todas las páginas de ambas vistas', (
    tester,
  ) async {
    final pedidos = <String>[];
    final sesion = sesionDePrueba((request) async {
      if (request.url.path == '/api/trabajo/reclamos') {
        final vista = request.url.queryParameters['vista']!;
        final cursor = request.url.queryParameters['cursor'];
        pedidos.add('$vista:${cursor ?? 'inicio'}');
        if (vista == 'asignados' && cursor == null) {
          return respuestaJson({
            'data': [_lista('pendiente')],
            'meta': {'next_cursor': 'siguiente'},
          }, 200);
        }
        return respuestaJson({
          'data': [],
          'meta': {'next_cursor': null},
        }, 200);
      }
      return respuestaJson({}, 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FTheme(data: FTheme.neutral.light.touch, child: child!),
        home: OperarioPage(sesion: sesion, mostrarMapaBase: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(
      pedidos,
      containsAll([
        'asignados:inicio',
        'asignados:siguiente',
        'disponibles:inicio',
      ]),
    );
    expect(find.text('1 reclamos asignados y disponibles'), findsOneWidget);
  });
}

class _TileFalso extends Fake implements TileImage {}

Map<String, dynamic> _lista(String estado) => {
  'id': 28,
  'titulo': 'Cable caído',
  'descripcion': 'Cable en el suelo',
  'direccion': 'Centro',
  'tipo': 'Energía eléctrica',
  'tipo_icono': 'electricidad',
  'estado': estado,
  'latitud': -45.85,
  'longitud': -67.49,
  'creado_en': '2026-10-22T12:30:00Z',
};

Map<String, dynamic> _detalle(String estado, bool asignado) => {
  ..._lista(estado),
  'tipo': tipoJson(),
  'fotos': <String>[],
  'responsable': asignado
      ? {'id': 7, 'nombre': 'Ana', 'apellido': 'Pérez'}
      : null,
  'historial': <Object>[],
};
