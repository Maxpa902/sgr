import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('shows the login when there is no saved session', (tester) async {
    final sesion = sesionDePrueba(sinServer);
    await sesion.restaurar();

    await tester.pumpWidget(SgrApp(sesion: sesion));

    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets(
    'goes straight to the home screen when the saved session is valid',
    (tester) async {
      final sesion = sesionDePrueba(
        (_) async => respuestaJson({'data': usuarioJson()}, 200),
        almacen: AlmacenTokenEnMemoria('1|abc'),
      );
      await sesion.restaurar();

      await tester.pumpWidget(SgrApp(sesion: sesion));

      expect(find.text('Hola, Ana'), findsOneWidget);
    },
  );

  testWidgets('logging out goes back to the login', (tester) async {
    final sesion = sesionDePrueba(
      (pedido) async => pedido.url.path == '/api/logout'
          ? http.Response('', 204)
          : respuestaJson({'data': usuarioJson()}, 200),
      almacen: AlmacenTokenEnMemoria('1|abc'),
    );
    await sesion.restaurar();
    await tester.pumpWidget(SgrApp(sesion: sesion));

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('offers to retry when the server does not answer', (
    tester,
  ) async {
    final sesion = sesionDePrueba(
      sinServer,
      almacen: AlmacenTokenEnMemoria('1|abc'),
    );
    await sesion.restaurar();

    await tester.pumpWidget(SgrApp(sesion: sesion));

    expect(find.text('Reintentar'), findsOneWidget);
  });
}
