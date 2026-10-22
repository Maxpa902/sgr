import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../mapa/estilos.dart';
import '../mapa/resumen_reclamo.dart';
import '../modelos/reclamo_mapa.dart';
import '../sesion/sesion.dart';

class MisReclamosPage extends StatefulWidget {
  const MisReclamosPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<MisReclamosPage> createState() => _MisReclamosPageState();
}

class _MisReclamosPageState extends State<MisReclamosPage> {
  late Future<List<ReclamoMapa>> _reclamosFuture;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _reclamosFuture = widget.sesion.misReclamos();
  }

  void _reintentar() {
    setState(_cargar);
  }

  void _mostrarDetalle(ReclamoMapa reclamo) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ResumenReclamo(reclamo: reclamo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Reclamos')),
      body: SafeArea(
        child: FutureBuilder<List<ReclamoMapa>>(
          future: _reclamosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final error = snapshot.error;
              final mensaje = error is ApiException
                  ? error.mensaje
                  : 'No se pudieron cargar tus reclamos.';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                      const SizedBox(height: 12),
                      Text(mensaje, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _reintentar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      )
                    ],
                  ),
                ),
              );
            }

            final reclamos = snapshot.data ?? [];
            if (reclamos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined, size: 48, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      const Text('Todavía no cargaste ningún reclamo.'),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _reintentar(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reclamos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final reclamo = reclamos[index];
                  final colorEstado = colorDelEstado(reclamo.estado);

                  return Card(
                    child: ListTile(
                      onTap: () => _mostrarDetalle(reclamo),
                      leading: CircleAvatar(
                        backgroundColor: colorEstado,
                        foregroundColor: Colors.white,
                        child: Icon(iconoDeCategoria(reclamo.tipo.icono)),
                      ),
                      title: Text(
                        reclamo.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Estado: ${nombreDelEstado(reclamo.estado)}',
                        style: TextStyle(
                          color: colorEstado,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}