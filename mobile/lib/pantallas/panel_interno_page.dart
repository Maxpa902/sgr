import 'package:flutter/material.dart';

import '../sesion/sesion.dart';
import 'usuarios_page.dart';

/// Pantalla inicial para los roles que gestionan o atienden reclamos.
class PanelInternoPage extends StatelessWidget {
  const PanelInternoPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    final usuario = sesion.usuario!;
    final esAdmin = usuario.esAdmin;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final modulos = esAdmin
        ? const [
            _ModuloInterno(
              icono: Icons.manage_accounts_outlined,
              titulo: 'Cuentas',
              detalle: 'Administración de usuarios',
            ),
            _ModuloInterno(
              icono: Icons.category_outlined,
              titulo: 'Tipos de reclamo',
              detalle: 'Categorías disponibles en la app',
            ),
            _ModuloInterno(
              icono: Icons.gavel_outlined,
              titulo: 'Sanciones',
              detalle: 'Revisión y seguimiento',
            ),
          ]
        : const [
            _ModuloInterno(
              icono: Icons.assignment_outlined,
              titulo: 'Atención de reclamos',
              detalle: 'Revisar y actualizar su estado',
            ),
            _ModuloInterno(
              icono: Icons.history_outlined,
              titulo: 'Actividad reciente',
              detalle: 'Seguimiento del trabajo realizado',
            ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SGR'),
        actions: [
          IconButton(
            onPressed: sesion.cerrarSesion,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('Hola, ${usuario.nombre}', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(
                  esAdmin ? Icons.shield_outlined : Icons.handyman_outlined,
                  size: 18,
                ),
                label: Text(usuario.rolParaMostrar),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              esAdmin ? 'Administración' : 'Operaciones',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              esAdmin
                  ? 'Accesos para administrar SGR.'
                  : 'Herramientas para atender reclamos.',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            for (var index = 0; index < modulos.length; index++) ...[
              _ModuloTile(
                modulo: modulos[index],
                alSeleccionar: esAdmin && index == 0
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => UsuariosPage(sesion: sesion),
                        ),
                      )
                    : null,
              ),
              if (index < modulos.length - 1) const Divider(height: 1),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      esAdmin
                          ? 'Los demás módulos de administración se habilitarán '
                              'a medida que se incorporen sus funciones.'
                          : 'Estos módulos se habilitarán a medida que se '
                              'incorporen las funciones de atención.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuloInterno {
  const _ModuloInterno({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
}

class _ModuloTile extends StatelessWidget {
  const _ModuloTile({required this.modulo, this.alSeleccionar});

  final _ModuloInterno modulo;
  final VoidCallback? alSeleccionar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: alSeleccionar,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(modulo.icono, color: colorScheme.onSecondaryContainer),
      ),
      title: Text(modulo.titulo),
      subtitle: Text(modulo.detalle),
      trailing: alSeleccionar == null
          ? Text(
              'Próximamente',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
    );
  }
}
