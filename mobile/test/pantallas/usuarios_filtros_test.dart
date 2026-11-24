import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:mobile/pantallas/usuarios_page.dart';
import 'package:mobile/tema/tema_app.dart';

import '../helpers.dart';

void main() {
  testWidgets('consulta personal y filtra vecinos por suspensión', (tester) async {
    final consultas = <Map<String, String>>[];
    final sesion = sesionDePrueba((pedido) async {
      consultas.add(pedido.url.queryParameters);
      return respuestaJson({'data': [], 'meta': {'total': 0}}, 200);
    });
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => FTheme(data: FTheme.neutral.light.touch, child: child!),
      home: TemaApp(child: UsuariosPage(sesion: sesion)),
    ));
    await tester.pumpAndSettle();

    expect(consultas.any((q) => q['rol'] == 'personal'), isTrue);
    await tester.tap(find.text('Vecinos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspendidos'));
    await tester.pumpAndSettle();
    expect(consultas.last['rol'], 'ciudadano');
    expect(consultas.last['suspension'], 'suspendidos');

    await tester.tap(find.text('Activos'));
    await tester.pumpAndSettle();
    expect(consultas.last['suspension'], 'activos');
  });
}
