import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../sesion/sesion.dart';
import '../widgets/componentes_ui.dart';

/// Datos de la cuenta y cierre de sesión para todos los roles.
class CuentaPage extends StatelessWidget {
  const CuentaPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    final usuario = sesion.usuario!;
    final telefono = usuario.telefono?.trim();
    final nombre = usuario.nombre.trim();
    final apellido = usuario.apellido.trim();
    final iniciales = [nombre, apellido]
        .where((parte) => parte.isNotEmpty)
        .map((parte) => parte.characters.first.toUpperCase())
        .join();
    final colores = context.theme.colors;
    return LayoutPagina(
      titulo: 'Mi cuenta',
      alVolver: () => Navigator.of(context).pop(),
      superficie: SuperficiePagina.bordeABorde,
      contenido: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: colores.muted,
                  foregroundColor: colores.foreground,
                  child: Text(
                    iniciales,
                    style: Theme.of(context).textTheme.titleLarge,
                    semanticsLabel: 'Iniciales: $iniciales',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$nombre $apellido'.trim(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colores.muted,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    usuario.rolParaMostrar,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Datos de contacto',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DatoCuenta(
                    icono: Icons.mail_outline,
                    etiqueta: 'Correo electrónico',
                    valor: usuario.email,
                  ),
                  if (telefono != null && telefono.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    _DatoCuenta(
                      icono: Icons.phone_outlined,
                      etiqueta: 'Teléfono',
                      valor: telefono,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FButton(
            variant: .destructive,
            prefix: const Icon(Icons.logout),
            onPress: () async {
              await sesion.cerrarSesion();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _DatoCuenta extends StatelessWidget {
  const _DatoCuenta({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(icono, color: context.theme.colors.mutedForeground),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 4),
            Text(valor, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    ],
  );
}
