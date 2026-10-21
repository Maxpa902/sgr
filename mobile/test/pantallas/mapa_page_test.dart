import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/mapa/pines.dart';
import 'package:mobile/pantallas/mapa_page.dart';
import 'package:mobile/ubicacion/servicio_ubicacion.dart';

import '../helpers.dart';

void main() {
  /// Abre el mapa con un server simulado. Devuelve los pedidos de reclamos que
  /// recibió el server, para revisar los filtros que mandó la app.
  Future<List<Uri>> mostrarMapa(
    WidgetTester tester, {
    List<Map<String, dynamic>> reclamos = const [],
    List<Map<String, dynamic>> tipos = const [],
    ServicioUbicacion? ubicacion,
    int statusReclamos = 200,
  }) async {
    final pedidos = <Uri>[];
    final sesion = sesionDePrueba(
      servidorConRutas({
        '/api/tipos-reclamo': (_) async => respuestaJson({'data': tipos}, 200),
        '/api/reclamos': (pedido) async {
          pedidos.add(pedido.url);
          return statusReclamos == 200
              ? respuestaJson({'data': reclamos}, 200)
              : respuestaJson({'message': 'Server Error'}, statusReclamos);
        },
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MapaPage(
          sesion: sesion,
          ubicacion: ubicacion ?? UbicacionSimulada(punto: _enComodoro),
          mostrarMapaBase: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return pedidos;
  }

  Finder pin(int id) => find.byKey(ValueKey('pin-$id'));

  testWidgets('shows a pin for each claim', (tester) async {
    await mostrarMapa(
      tester,
      reclamos: [
        reclamoJson(id: 1, latitud: -45.8630, longitud: -67.4856),
        reclamoJson(id: 2, latitud: -45.8757, longitud: -67.5156),
      ],
    );

    expect(pin(1), findsOneWidget);
    expect(pin(2), findsOneWidget);
  });

  testWidgets('asks only for open claims when the map opens', (tester) async {
    final pedidos = await mostrarMapa(tester);

    expect(
      pedidos.single.queryParametersAll['estados[]'],
      unorderedEquals(['pendiente', 'en_proceso']),
    );
    expect(pedidos.single.queryParameters, isNot(contains('tipos[]')));
  });

  testWidgets('also asks for resolved claims after turning on that filter', (
    tester,
  ) async {
    final pedidos = await mostrarMapa(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Resueltos'));
    await tester.pumpAndSettle();

    expect(
      pedidos.last.queryParametersAll['estados[]'],
      unorderedEquals(['pendiente', 'en_proceso', 'resuelto']),
    );
  });

  testWidgets('asks only for the categories left on', (tester) async {
    final pedidos = await mostrarMapa(
      tester,
      tipos: [
        tipoJson(id: 1, nombre: 'Energía eléctrica', icono: 'electricidad'),
        tipoJson(id: 3, nombre: 'Agua potable', icono: 'agua'),
      ],
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Energía eléctrica'));
    await tester.pumpAndSettle();

    expect(pedidos.last.queryParametersAll['tipos[]'], ['3']);
  });

  testWidgets('shows the summary of a claim when tapping its pin', (
    tester,
  ) async {
    await mostrarMapa(
      tester,
      reclamos: [
        reclamoJson(
          id: 1,
          titulo: 'Cable caído en la esquina',
          direccion: 'Centro',
          confirmaciones: 7,
          desmentidas: 1,
        ),
      ],
    );

    await tester.tap(pin(1));
    await tester.pumpAndSettle();

    expect(find.text('Cable caído en la esquina'), findsOneWidget);
    expect(find.text('Energía eléctrica · Centro'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('7 confirman'), findsOneWidget);
    expect(find.text('1 lo desmiente'), findsOneWidget);
    expect(
      find.text('Muchos vecinos confirmaron este reclamo.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the number of confirmations on the pin', (tester) async {
    await mostrarMapa(
      tester,
      reclamos: [
        reclamoJson(id: 1, confirmaciones: 12),
        reclamoJson(id: 2, latitud: -45.8757, longitud: -67.5156),
      ],
    );

    expect(
      find.descendant(of: pin(1), matching: find.text('12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pin(2), matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets('groups pins that are very close together', (tester) async {
    await mostrarMapa(
      tester,
      reclamos: [
        reclamoJson(id: 1, latitud: -45.8829, longitud: -67.5160),
        reclamoJson(id: 2, latitud: -45.8831, longitud: -67.5162),
      ],
    );

    expect(find.byType(BurbujaDeReclamos), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BurbujaDeReclamos),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(pin(1), findsNothing);
  });

  testWidgets('says so when no claim matches the filters', (tester) async {
    await mostrarMapa(tester);

    expect(find.text('No hay reclamos con estos filtros.'), findsOneWidget);
  });

  testWidgets('offers to retry when the claims cannot be loaded', (
    tester,
  ) async {
    await mostrarMapa(tester, statusReclamos: 500);

    expect(
      find.text('Ocurrió un error en el servidor. Intentá de nuevo más tarde.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('marks your position when you are inside the map area', (
    tester,
  ) async {
    await mostrarMapa(tester, ubicacion: UbicacionSimulada(punto: _enComodoro));

    await tester.tap(find.byTooltip('Mi ubicación'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mi-ubicacion')), findsOneWidget);
  });

  testWidgets('warns when your position is outside the map area', (
    tester,
  ) async {
    // La ubicación que usa por defecto el emulador de Android: California.
    await mostrarMapa(
      tester,
      ubicacion: UbicacionSimulada(punto: const LatLng(37.422, -122.084)),
    );

    await tester.tap(find.byTooltip('Mi ubicación'));
    await tester.pump();

    expect(find.textContaining('fuera de la zona del mapa'), findsOneWidget);
    expect(find.byKey(const ValueKey('mi-ubicacion')), findsNothing);
  });

  testWidgets('explains why the location is not available', (tester) async {
    await mostrarMapa(
      tester,
      ubicacion: UbicacionSimulada(
        error: const UbicacionException(
          'Activá la ubicación del celular para usar esta función.',
        ),
      ),
    );

    await tester.tap(find.byTooltip('Mi ubicación'));
    await tester.pump();

    expect(
      find.text('Activá la ubicación del celular para usar esta función.'),
      findsOneWidget,
    );
  });
}

/// Un punto en el centro de Comodoro Rivadavia.
const _enComodoro = LatLng(-45.865, -67.482);
