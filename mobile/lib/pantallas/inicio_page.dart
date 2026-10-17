import 'package:flutter/material.dart';

import '../sesion/sesion.dart';

/// Pantalla provisoria después de iniciar sesión. En el paso 3 la reemplaza
/// el mapa de reclamos.
class InicioPage extends StatelessWidget {
  const InicioPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    // La app solo muestra esta pantalla cuando hay una sesión iniciada.
    final usuario = sesion.usuario!;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('SGR')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.waving_hand_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Hola, ${usuario.nombre}',
                  textAlign: TextAlign.center,
                  style: textos.headlineMedium,
                ),
                const SizedBox(height: 8),
                Chip(label: Text(usuario.rolParaMostrar)),
                const SizedBox(height: 24),
                Text(
                  'Pronto vas a ver acá el mapa con los reclamos de la ciudad.',
                  textAlign: TextAlign.center,
                  style: textos.bodyLarge,
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: sesion.cerrarSesion,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
