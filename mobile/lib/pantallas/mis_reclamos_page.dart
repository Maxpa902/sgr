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
      builder: (_) => ResumenReclamo(
        reclamo: reclamo,
        sesion: widget.sesion,
        alVotar: _reintentar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Reclamos'),
          actions: [
            IconButton(
              onPressed: _reintentar,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.person_pin_outlined),
                text: 'Creados por mí',
              ),
              Tab(
                icon: Icon(Icons.how_to_vote_outlined),
                text: 'Suscritos / Votados',
              ),
            ],
          ),
        ),
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
                        Icon(Icons.error_outline,
                            size: 48, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text(mensaje, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _reintentar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final reclamos = snapshot.data ?? [];
              final miUsuarioId = widget.sesion.usuario?.id;

              final misCreados = reclamos
                  .where((r) => miUsuarioId != null && r.usuarioId == miUsuarioId)
                  .toList();

              final suscritos = reclamos
                  .where((r) => miUsuarioId == null || r.usuarioId != miUsuarioId)
                  .toList();

              return TabBarView(
                children: [
                  _ListaReclamosTab(
                    reclamos: misCreados,
                    mensajeVacio: 'Todavía no cargaste ningún reclamo.',
                    iconoVacio: Icons.assignment_outlined,
                    onRefresh: _reintentar,
                    alTocar: _mostrarDetalle,
                    esSuscritos: false,
                  ),
                  _ListaReclamosTab(
                    reclamos: suscritos,
                    mensajeVacio:
                        'No estás suscrito ni votaste reclamos de otros vecinos.',
                    iconoVacio: Icons.how_to_vote_outlined,
                    onRefresh: _reintentar,
                    alTocar: _mostrarDetalle,
                    esSuscritos: true,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ListaReclamosTab extends StatelessWidget {
  const _ListaReclamosTab({
    required this.reclamos,
    required this.mensajeVacio,
    required this.iconoVacio,
    required this.onRefresh,
    required this.alTocar,
    this.esSuscritos = false,
  });

  final List<ReclamoMapa> reclamos;
  final String mensajeVacio;
  final IconData iconoVacio;
  final VoidCallback onRefresh;
  final ValueChanged<ReclamoMapa> alTocar;
  final bool esSuscritos;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (reclamos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconoVacio, size: 48, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(mensajeVacio, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reclamos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final reclamo = reclamos[index];
          final colorEstado = colorDelEstado(reclamo.estado);

          final esAfirmativo = reclamo.miVoto == 'confirma';
          final esDesmentido = reclamo.miVoto == 'desmiente';

          return Card(
            child: ListTile(
              onTap: () => alTocar(reclamo),
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
              subtitle: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    'Estado: ${nombreDelEstado(reclamo.estado)}',
                    style: TextStyle(
                      color: colorEstado,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (esSuscritos && (esAfirmativo || esDesmentido))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: esAfirmativo
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            esAfirmativo ? Icons.thumb_up : Icons.thumb_down,
                            size: 12,
                            color: esAfirmativo
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            esAfirmativo ? 'Confirmaste' : 'Desmentiste',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: esAfirmativo
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}