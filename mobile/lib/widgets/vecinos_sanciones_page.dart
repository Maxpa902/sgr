import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../formato.dart';
import '../modelos/usuario.dart';
import '../pantallas/sanciones_vecino_page.dart';
import '../sesion/sesion.dart';
import '../tema/tema_app.dart';
import 'componentes_ui.dart';

/// Vecinos suspendidos por reclamos falsos. Tocar uno abre sus sanciones para revocarlas.
class VecinosSancionesPage extends StatefulWidget {
  const VecinosSancionesPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<VecinosSancionesPage> createState() => _VecinosSancionesPageState();
}

class _VecinosSancionesPageState extends State<VecinosSancionesPage> {
  late Future<List<Usuario>> _futuroUsuarios;

  @override
  void initState() {
    super.initState();
    _futuroUsuarios = _pedirUsuarios();
  }

  Future<List<Usuario>> _pedirUsuarios() =>
      widget.sesion.obtenerUsuariosConSancionesOrdenados();

  void _recargar() {
    setState(() {
      _futuroUsuarios = _pedirUsuarios();
    });
  }

  Future<void> _abrirSanciones(Usuario vecino) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemaApp(
          child: SancionesVecinoPage(sesion: widget.sesion, vecino: vecino),
        ),
      ),
    );
    // Si se revocó una sanción, el vecino puede haber dejado de estar suspendido.
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vecinos suspendidos')),
      body: FutureBuilder<List<Usuario>>(
        future: _futuroUsuarios,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: FCircularProgress());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return EstadoContenido(
              tipo: EstadoContenidoTipo.error,
              titulo: 'No se pudieron cargar los vecinos',
              descripcion: error is ApiException ? error.mensaje : null,
              accion: AccionContenido(
                etiqueta: 'Reintentar',
                alActivar: _recargar,
              ),
            );
          }

          final suspendidos = (snapshot.data ?? [])
              .where((vecino) => vecino.estaSuspendido)
              .toList();
          if (suspendidos.isEmpty) {
            return const EstadoContenido(
              tipo: EstadoContenidoTipo.vacio,
              titulo: 'No hay vecinos suspendidos',
              descripcion:
                  'Cuando se rechaza un reclamo por falso, su creador aparece '
                  'acá durante los 30 días de suspensión.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: suspendidos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final vecino = suspendidos[index];
              return FTile(
                prefix: Icon(Icons.block, color: context.theme.colors.error),
                title: Text('${vecino.nombre} ${vecino.apellido}'),
                subtitle: Text(
                  '${vecino.email}\n'
                  'Suspendido hasta el ${fechaCorta(vecino.suspendidoHasta!)}',
                ),
                suffix: const Icon(Icons.chevron_right),
                onPress: () => _abrirSanciones(vecino),
              );
            },
          );
        },
      ),
    );
  }
}
