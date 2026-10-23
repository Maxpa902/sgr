import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'api/api_client.dart';
import 'config.dart';
import 'pantallas/cargando_page.dart';
import 'pantallas/login_page.dart';
import 'pantallas/panel_interno_page.dart';
import 'pantallas/mapa_page.dart';
import 'pantallas/sin_conexion_page.dart';
import 'sesion/almacen_token.dart';
import 'sesion/sesion.dart';

void main() {
  // Hace falta antes de leer el token guardado, que usa código nativo de Android.
  WidgetsFlutterBinding.ensureInitialized();

  final sesion = Sesion(
    api: ApiClient(baseUrl: serverUrl),
    almacen: AlmacenTokenSeguro(),
  );
  sesion.restaurar();

  runApp(SgrApp(sesion: sesion));
}

class SgrApp extends StatelessWidget {
  const SgrApp({super.key, required this.sesion, this.mostrarMapaBase = true});

  final Sesion sesion;

  /// Los tests lo apagan para que el mapa no descargue imágenes de internet.
  final bool mostrarMapaBase;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SGR',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B5B)),
        useMaterial3: true,
      ),
      builder: (context, child) =>
          FTheme(data: FTheme.neutral.light.touch, child: child!),
      // Cada vez que la sesión avisa un cambio, se vuelve a elegir la pantalla.
      home: ListenableBuilder(
        listenable: sesion,
        builder: (context, _) => switch (sesion.estado) {
          EstadoSesion.cargando => const CargandoPage(),
          EstadoSesion.sinConexion => SinConexionPage(
            alReintentar: sesion.restaurar,
          ),
          EstadoSesion.sinSesion => LoginPage(sesion: sesion),
          EstadoSesion.conSesion => _inicioDeSesion(sesion),
        },
      ),
    );
  }

  Widget _inicioDeSesion(Sesion sesion) {
    final usuario = sesion.usuario!;

    if (usuario.esAdmin || usuario.esOperario) {
      return PanelInternoPage(sesion: sesion);
    }

    return PantallaPrincipal(sesion: sesion, mostrarMapaBase: mostrarMapaBase);
  }
}
