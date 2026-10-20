import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../modelos/usuario.dart';
import '../sesion/sesion.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  late Future<List<Usuario>> _usuarios;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _usuarios = widget.sesion.listarUsuarios();
  }

  void _reintentar() {
    setState(_cargar);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas')),
      body: SafeArea(
        child: FutureBuilder<List<Usuario>>(
          future: _usuarios,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final error = snapshot.error;
              final mensaje = error is ApiException
                  ? error.mensaje
                  : 'No se pudieron cargar las cuentas.';
              return _EstadoDirectorio(
                icono: Icons.cloud_off_outlined,
                titulo: 'No se pudo cargar',
                detalle: mensaje,
                accion: FilledButton.icon(
                  onPressed: _reintentar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              );
            }

            final usuarios = snapshot.data ?? const <Usuario>[];
            if (usuarios.isEmpty) {
              return _EstadoDirectorio(
                icono: Icons.people_outline,
                titulo: 'Todavía no hay cuentas',
                detalle: 'Cuando se registren usuarios, aparecerán acá.',
                accion: OutlinedButton.icon(
                  onPressed: _reintentar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                _reintentar();
                try {
                  await _usuarios;
                } on Object {
                  // El FutureBuilder muestra el error y deja disponible reintentar.
                }
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                itemCount: usuarios.length + 1,
                separatorBuilder: (_, index) => index == 0
                    ? const SizedBox(height: 12)
                    : const Divider(height: 1, indent: 68),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Usuarios',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${usuarios.length}',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return _UsuarioTile(usuario: usuarios[index - 1]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UsuarioTile extends StatelessWidget {
  const _UsuarioTile({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final nombre = '${usuario.nombre} ${usuario.apellido}'.trim();
    final colorEstado = usuario.activo == false
        ? colorScheme.error
        : colorScheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        child: Text(
          usuario.nombre.isEmpty ? '?' : usuario.nombre[0].toUpperCase(),
        ),
      ),
      title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(usuario.email, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                usuario.rolParaMostrar,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (usuario.activo != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: colorEstado),
                    const SizedBox(width: 5),
                    Text(
                      usuario.activo! ? 'Activa' : 'Inactiva',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorEstado,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstadoDirectorio extends StatelessWidget {
  const _EstadoDirectorio({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.accion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget accion;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            accion,
          ],
        ),
      ),
    );
  }
}
