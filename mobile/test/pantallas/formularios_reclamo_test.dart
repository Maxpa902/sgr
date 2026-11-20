import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/modelos/reclamo_mapa.dart';
import 'package:mobile/modelos/tipo_reclamo.dart';
import 'package:mobile/modelos/usuario.dart';
import 'package:mobile/pantallas/crear_reclamo_page.dart';
import 'package:mobile/pantallas/editar_reclamo_page.dart';
import 'package:mobile/sesion/sesion.dart';
import 'package:mobile/tema/tema_app.dart';

import '../helpers.dart';

class _ApiSimulada extends ApiClient {
  _ApiSimulada() : super(baseUrl: 'http://server');

  int ediciones = 0;

  @override
  Future<Usuario> usuarioActual() async => Usuario.fromJson(usuarioJson());

  @override
  Future<List<TipoReclamo>> tiposDeReclamo() async => [
    TipoReclamo.fromJson(tipoJson()),
  ];

  @override
  Future<List<ReclamoMapa>> misReclamos() async => [];

  @override
  Future<ReclamoMapa> editarReclamo({
    required int id,
    required String titulo,
    required String descripcion,
    required double latitud,
    required double longitud,
    List<int> fotosEliminar = const [],
    List<File> nuevasImagenes = const [],
  }) async {
    ediciones++;
    throw const ApiException(
      'Revisá los datos.',
      statusCode: 422,
      errores: {'titulo': 'Título rechazado por el servidor.'},
    );
  }
}

void main() {
  testWidgets('crear exige categoría, título y descripción antes de enviar', (
    tester,
  ) async {
    final api = _ApiSimulada();
    final sesion = Sesion(api: api, almacen: AlmacenTokenEnMemoria());
    await tester.pumpWidget(
      MaterialApp(home: TemaApp(child: CrearReclamoPage(sesion: sesion))),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Enviar Reclamo'));
    await tester.tap(find.text('Enviar Reclamo'));
    await tester.pumpAndSettle();

    expect(find.text('Seleccioná un tipo de reclamo.'), findsOneWidget);
    expect(find.text('Ingresá un título.'), findsOneWidget);
    expect(find.text('Ingresá una descripción.'), findsOneWidget);
  });

  testWidgets('editar conserva datos iniciales y muestra errores del servidor', (
    tester,
  ) async {
    final api = _ApiSimulada();
    final sesion = Sesion(api: api, almacen: AlmacenTokenEnMemoria());
    final reclamo = ReclamoMapa.fromJson({
      ...reclamoJson(titulo: 'Cable caído'),
      'descripcion': 'Cable sobre la vereda',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: TemaApp(
          child: EditarReclamoPage(reclamo: reclamo, sesion: sesion),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cable caído'), findsOneWidget);
    expect(find.text('Cable sobre la vereda'), findsOneWidget);
    expect(find.text('Energía eléctrica'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<TipoReclamo>), findsNothing);
    expect(find.byType(FTextFormField), findsNWidgets(2));

    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(api.ediciones, 1);
    expect(find.text('Revisá los datos.'), findsOneWidget);
    expect(find.text('Título rechazado por el servidor.'), findsOneWidget);
    expect(find.text('Cable caído'), findsOneWidget);
  });
}
