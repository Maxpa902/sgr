import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/sesion/sesion.dart';
import 'package:mobile/widgets/comentarios_reclamo.dart';

import '../helpers.dart';

void main() {
  const rutaComentarios = '/api/reclamos/5/comentarios';

  Map<String, dynamic> comentarioJson({
    required int id,
    required String contenido,
    String autor = 'Luis Gómez',
    bool esMio = false,
  }) => {
    'id': id,
    'contenido': contenido,
    'autor': autor,
    'es_mio': esMio,
    'editado': false,
    'creado_en': DateTime.now()
        .subtract(const Duration(hours: 2))
        .toUtc()
        .toIso8601String(),
  };

  Map<String, dynamic> listado(
    List<Map<String, dynamic>> comentarios, {
    int disponibles = 3,
    String? motivoBloqueo,
    bool puedeModificarPropios = true,
  }) => {
    'data': comentarios,
    'meta': {
      'disponibles': disponibles,
      'motivo_bloqueo': motivoBloqueo,
      'puede_modificar_propios': puedeModificarPropios,
    },
  };

  Future<void> mostrarComentarios(WidgetTester tester, Sesion sesion) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ComentariosReclamo(sesion: sesion, reclamoId: 5),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('publica un comentario y recarga la lista', (tester) async {
    final comentarios = [comentarioJson(id: 1, contenido: 'Pasa hace días')];
    Map<String, dynamic>? cuerpoEnviado;
    final sesion = sesionDePrueba((pedido) async {
      if (pedido.url.path != rutaComentarios) {
        return respuestaJson({'message': 'Not Found.'}, 404);
      }
      if (pedido.method == 'POST') {
        cuerpoEnviado = jsonDecode(pedido.body) as Map<String, dynamic>;
        comentarios.add(
          comentarioJson(
            id: 2,
            contenido: 'Sigue igual',
            autor: 'Ana Pérez',
            esMio: true,
          ),
        );
        return respuestaJson({'data': comentarios.last}, 201);
      }
      return respuestaJson(
        listado(comentarios, disponibles: 4 - comentarios.length),
        200,
      );
    });
    await mostrarComentarios(tester, sesion);
    expect(find.text('Pasa hace días'), findsOneWidget);
    expect(
      find.text('Te quedan 3 comentarios en este reclamo'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '  Sigue igual  ');
    await tester.tap(find.text('Comentar'));
    await tester.pumpAndSettle();

    expect(cuerpoEnviado, {'contenido': 'Sigue igual'});
    expect(find.text('Sigue igual'), findsOneWidget);
    expect(
      find.text('Te quedan 2 comentarios en este reclamo'),
      findsOneWidget,
    );
    expect(find.byTooltip('Borrar comentario'), findsOneWidget);
  });

  testWidgets('muestra el motivo cuando no se puede comentar', (tester) async {
    final sesion = sesionDePrueba(
      servidorConRutas({
        rutaComentarios: (_) async => respuestaJson(
          listado(
            [comentarioJson(id: 1, contenido: 'Mío', esMio: true)],
            motivoBloqueo:
                'El reclamo ya finalizó: los comentarios están cerrados.',
            puedeModificarPropios: false,
          ),
          200,
        ),
      }),
    );

    await mostrarComentarios(tester, sesion);

    expect(
      find.text('El reclamo ya finalizó: los comentarios están cerrados.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Editar comentario'), findsNothing);
  });

  testWidgets('borra un comentario propio después de confirmar', (
    tester,
  ) async {
    var borrado = false;
    final sesion = sesionDePrueba((pedido) async {
      if (pedido.method == 'DELETE' &&
          pedido.url.path == '/api/comentarios/7') {
        borrado = true;
        return respuestaJson(null, 204);
      }
      if (pedido.url.path == rutaComentarios) {
        return respuestaJson(
          listado([
            if (!borrado) comentarioJson(id: 7, contenido: 'Mío', esMio: true),
          ]),
          200,
        );
      }
      return respuestaJson({'message': 'Not Found.'}, 404);
    });
    await mostrarComentarios(tester, sesion);

    await tester.tap(find.byTooltip('Borrar comentario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(borrado, isTrue);
    expect(find.text('Mío'), findsNothing);
    expect(find.text('Todavía no hay comentarios.'), findsOneWidget);
  });

  testWidgets('edita un comentario propio y envía el texto nuevo', (
    tester,
  ) async {
    Map<String, dynamic>? cuerpoEnviado;
    final sesion = sesionDePrueba((pedido) async {
      if (pedido.method == 'PATCH' && pedido.url.path == '/api/comentarios/7') {
        cuerpoEnviado = jsonDecode(pedido.body) as Map<String, dynamic>;
        return respuestaJson({'data': {}}, 200);
      }
      if (pedido.url.path == rutaComentarios) {
        return respuestaJson(
          listado([
            comentarioJson(
              id: 7,
              contenido: cuerpoEnviado?['contenido'] as String? ?? 'Con eror',
              esMio: true,
            ),
          ]),
          200,
        );
      }
      return respuestaJson({'message': 'Not Found.'}, 404);
    });
    await mostrarComentarios(tester, sesion);

    await tester.tap(find.byTooltip('Editar comentario'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Con error corregido');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(cuerpoEnviado, {'contenido': 'Con error corregido'});
    expect(find.text('Con error corregido'), findsOneWidget);
  });
}
