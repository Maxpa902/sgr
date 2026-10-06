import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('shows the welcome screen and server status button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SgrApp());

    expect(find.text('Bienvenido a SGR'), findsOneWidget);
    expect(find.text('Sistema de gestión de reclamos'), findsOneWidget);
    expect(find.text('Leer estado del servidor'), findsOneWidget);
    expect(find.text('Todavía no se consultó el servidor.'), findsOneWidget);
  });
}
