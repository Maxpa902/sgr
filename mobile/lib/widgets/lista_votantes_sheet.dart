import 'package:flutter/material.dart';
import '../api/api_exception.dart';
import '../sesion/sesion.dart';
import '../tema/colores.dart';

class ListaVotantesSheet extends StatefulWidget {
  const ListaVotantesSheet({super.key, required this.sesion, required this.reclamoId});

  final Sesion sesion;
  final int reclamoId;

  static void mostrar(BuildContext context, {required Sesion sesion, required int reclamoId}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ListaVotantesSheet(
        sesion: sesion,
        reclamoId: reclamoId,
      ),
    );
  }

  @override
  State<ListaVotantesSheet> createState() => _ListaVotantesSheetState();
}

class _ListaVotantesSheetState extends State<ListaVotantesSheet> {
  late Future<List<Map<String, dynamic>>> _votantes;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _votantes = widget.sesion.obtenerVotantes(widget.reclamoId);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _votantes,
            builder: (context, snapshot) {
              final cargando = snapshot.connectionState != ConnectionState.done;
              final votantes = snapshot.data ?? [];
              final confirmaciones = votantes.where((v) => v['valor'] == 'confirma').toList();
              final desmentidas = votantes.where((v) => v['valor'] != 'confirma').toList();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Votos del reclamo', style: textos.titleLarge),
                      ),
                      if (!cargando && !snapshot.hasError)
                        Text(
                          '${votantes.length} ${votantes.length == 1 ? 'voto' : 'votos'}',
                          style: textos.bodyMedium?.copyWith(
                            color: ColoresApp.textoSecundario,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (cargando)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError) ...[
                    Text(
                      snapshot.error is ApiException
                          ? (snapshot.error! as ApiException).mensaje
                          : 'No se pudieron cargar los votos.',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(_cargar),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ),
                  ] else if (votantes.isEmpty)
                    const Text('Aún no hay votos registrados para este reclamo.')
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (confirmaciones.isNotEmpty)
                              _GrupoVotantes(
                                titulo: 'Confirmaciones',
                                icono: Icons.thumb_up_outlined,
                                color: ColoresApp.exito,
                                votantes: confirmaciones,
                              ),
                            if (confirmaciones.isNotEmpty && desmentidas.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1),
                              ),
                            if (desmentidas.isNotEmpty)
                              _GrupoVotantes(
                                titulo: 'Desmentidas',
                                icono: Icons.thumb_down_outlined,
                                color: ColoresApp.error,
                                votantes: desmentidas,
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
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

class _GrupoVotantes extends StatelessWidget {
  const _GrupoVotantes({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.votantes,
  });

  final String titulo;
  final IconData icono;
  final Color color;
  final List<Map<String, dynamic>> votantes;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$titulo · ${votantes.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      for (final voto in votantes)
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 0, 8),
          child: Text(
            voto['usuario'] as String? ?? 'Usuario',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
    ],
  );
}
