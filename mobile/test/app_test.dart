import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart';
import 'package:mobile/pantallas/mapa_page.dart';

import 'helpers.dart';

void main() {
  /// Un server con una sesión válida y el mapa vacío.
  MockClientHandler serverConSesion() {
    return servidorConRutas({
      '/api/usuario': (_) async => respuestaJson({'data': usuarioJson()}, 200),
      '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
      '/api/reclamos': (_) async => respuestaJson({'data': []}, 200),
      '/api/logout': (_) async => http.Response('', 204),
    });
  }

  testWidgets('shows the login when there is no saved session', (tester) async {
    final sesion = sesionDePrueba(sinServer);
    await sesion.restaurar();

    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));

    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('goes straight to the map when the saved session is valid', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      serverConSesion(),
      almacen: AlmacenTokenEnMemoria('1|abc'),
    );
    await sesion.restaurar();

    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
    await tester.pumpAndSettle();

    expect(find.byType(MapaPage), findsOneWidget);
  });

  testWidgets('logging out from the account menu goes back to the login', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      serverConSesion(),
      almacen: AlmacenTokenEnMemoria('1|abc'),
    );
    await sesion.restaurar();
    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('el vecino navega y actualiza sus reclamos vacíos', (tester) async {
    var pedidosMisReclamos = 0;
    final sesion = sesionDePrueba(
      servidorConRutas({
        '/api/usuario': (_) async => respuestaJson({'data': usuarioJson()}, 200),
        '/api/tipos-reclamo': (_) async => respuestaJson({'data': []}, 200),
        '/api/reclamos': (pedido) async {
          if (pedido.url.queryParameters['mis_reclamos'] == '1') {
            pedidosMisReclamos++;
          }
          return respuestaJson({'data': []}, 200);
        },
      }),
      almacen: AlmacenTokenEnMemoria('1|abc'),
    );
    await sesion.restaurar();
    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reclamos')));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no cargaste ningún reclamo.'), findsOneWidget);
    final anteriores = pedidosMisReclamos;
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(pedidosMisReclamos, anteriores + 1);

    await tester.tap(find.byKey(const ValueKey('mapa')));
    await tester.pumpAndSettle();
    expect(find.byType(MapaPage), findsOneWidget);
  });

  testWidgets('offers to retry when the server does not answer', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      sinServer,
      almacen: AlmacenTokenEnMemoria('1|abc'),
    );
    await sesion.restaurar();

    await tester.pumpWidget(SgrApp(sesion: sesion, mostrarMapaBase: false));

    expect(find.text('Reintentar'), findsOneWidget);
  });
}
