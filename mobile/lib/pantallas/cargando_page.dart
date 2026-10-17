import 'package:flutter/material.dart';

/// Se muestra al abrir la app, mientras se revisa si hay una sesión guardada.
class CargandoPage extends StatelessWidget {
  const CargandoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
