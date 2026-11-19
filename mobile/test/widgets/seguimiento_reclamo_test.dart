import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/sesion/sesion.dart';
import 'package:mobile/widgets/seguimiento_reclamo.dart';

import '../helpers.dart';

void main() {
  const rutaHistorial = '/api/reclamos/5/historial';

  final historialJson = {
    'data': [
      {
        'id': 1,
        'estado': 'pendiente',
        'observacion': null,
        'creado_en': '2026-11-18T12:00:00+00:00',
      },
      {
        'id': 2,
        'estado': 'en_proceso',
        'observacion': null,
        'creado_en': '2026-11-19T12:00:00+00:00',
      },
      {
        'id': 3,
        'estado': 'resuelto',
        'observacion': 'Se reparó el cable',
        'creado_en': '2026-11-21T12:00:00+00:00',
      },
    ],
  };

  Future<void> mostrarSeguimiento(WidgetTester tester, Sesion sesion) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SeguimientoReclamo(sesion: sesion, reclamoId: 5)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'muestra cada cambio como Cooperativa con su observación pública',
    (tester) async {
      final sesion = sesionDePrueba(
        servidorConRutas({
          rutaHistorial: (_) async => respuestaJson(historialJson, 200),
        }),
      );

      await mostrarSeguimiento(tester, sesion);

      expect(find.textContaining('Pendiente ·'), findsOneWidget);
      expect(find.text('Reclamo cargado'), findsOneWidget);
      expect(find.textContaining('En proceso ·'), findsOneWidget);
      expect(find.text('Cooperativa'), findsOneWidget);
      expect(find.textContaining('Resuelto ·'), findsOneWidget);
      expect(find.text('Cooperativa: Se reparó el cable'), findsOneWidget);
    },
  );

  testWidgets('si falla la carga, deja reintentar', (tester) async {
    var pedidos = 0;
    final sesion = sesionDePrueba(
      servidorConRutas({
        rutaHistorial: (_) async {
          pedidos++;
          return pedidos == 1
              ? respuestaJson({'message': 'Error del server.'}, 500)
              : respuestaJson(historialJson, 200);
        },
      }),
    );
    await mostrarSeguimiento(tester, sesion);
    expect(find.text('No se pudo cargar el seguimiento.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(pedidos, 2);
    expect(find.text('Cooperativa: Se reparó el cable'), findsOneWidget);
  });
}
