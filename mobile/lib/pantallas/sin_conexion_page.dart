import 'package:flutter/material.dart';

/// Se muestra cuando hay una sesión guardada pero el server no respondió.
class SinConexionPage extends StatelessWidget {
  const SinConexionPage({super.key, required this.alReintentar});

  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64),
                const SizedBox(height: 16),
                Text(
                  'No se pudo conectar con el servidor',
                  textAlign: TextAlign.center,
                  style: textos.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Revisá tu conexión a internet e intentá de nuevo.',
                  textAlign: TextAlign.center,
                  style: textos.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: alReintentar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
