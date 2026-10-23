import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../sesion/sesion.dart';
import 'reclamos_admin_page.dart';
import 'usuarios_page.dart';

/// Pantalla inicial para los roles que gestionan o atienden reclamos.
class PanelInternoPage extends StatelessWidget {
  const PanelInternoPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    final usuario = sesion.usuario!;
    if (usuario.esAdmin) {
      return _VistaAdmin(sesion: sesion);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const modulos = [
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
                avatar: Icon(Icons.handyman_outlined, size: 18),
                label: Text(usuario.rolParaMostrar),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Operaciones',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Herramientas para atender reclamos.',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            for (var index = 0; index < modulos.length; index++) ...[
              _ModuloTile(modulo: modulos[index], alSeleccionar: null),
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
                      'Estos módulos se habilitarán a medida que se '
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

class _VistaAdmin extends StatelessWidget {
  const _VistaAdmin({required this.sesion});

  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      header: FHeader(
        title: const Text('SGR'),
        suffixes: [
          FHeaderAction(
            icon: const Icon(Icons.account_circle_outlined),
            semanticsTooltip: 'Cuenta',
            onPress: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _CuentaAdminPage(sesion: sesion),
              ),
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'Administración',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Consulta cuentas y reclamos del sistema.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 28),
          Text('Gestión', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FCard(
            child: FTappable(
              semanticsButton: true,
              semanticsLabel: 'Cuentas',
              onPress: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UsuariosPage(sesion: sesion),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_outlined,
                      color: context.theme.colors.foreground,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cuentas',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Consultá las cuentas registradas',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.theme.colors.mutedForeground,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: context.theme.colors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FCard(
            child: FTappable(
              semanticsButton: true,
              semanticsLabel: 'Reclamos',
              onPress: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReclamosAdminPage(sesion: sesion),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      color: context.theme.colors.foreground,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reclamos',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Consultá los reclamos registrados',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.theme.colors.mutedForeground,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: context.theme.colors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CuentaAdminPage extends StatelessWidget {
  const _CuentaAdminPage({required this.sesion});

  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    final usuario = sesion.usuario!;
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('Cuenta'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: 52,
                      color: context.theme.colors.mutedForeground,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${usuario.nombre} ${usuario.apellido}'.trim(),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usuario.email,
                      style: TextStyle(
                        color: context.theme.colors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
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
