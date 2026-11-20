import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../api/api_exception.dart';
import '../sesion/sesion.dart';
import '../tema/colores.dart';
import 'componentes_ui.dart';

class ListaVotantesSheet extends StatefulWidget {
  const ListaVotantesSheet({
    super.key,
    required this.sesion,
    required this.reclamoId,
  });

  final Sesion sesion;
  final int reclamoId;

  static void mostrar(
    BuildContext context, {
    required Sesion sesion,
    required int reclamoId,
  }) {
    PanelInferior(
      titulo: 'Votos del reclamo',
      proporcionAlturaMaxima: 0.75,
      contenido: ListaVotantesSheet(sesion: sesion, reclamoId: reclamoId),
    ).mostrar<void>(context);
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _votantes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.error is ApiException
                    ? (snapshot.error! as ApiException).mensaje
                    : 'No se pudieron cargar los votos.',
              ),
              const SizedBox(height: 8),
              FButton(
                variant: .outline,
                onPress: () => setState(_cargar),
                child: const Text('Reintentar'),
              ),
            ],
          );
        }
        final votantes = snapshot.data ?? [];
        if (votantes.isEmpty) {
          return const Text('Aún no hay votos registrados para este reclamo.');
        }
        final confirmaciones = votantes
            .where((v) => v['valor'] == 'confirma')
            .toList();
        final desmentidas = votantes
            .where((v) => v['valor'] != 'confirma')
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${votantes.length} ${votantes.length == 1 ? 'voto' : 'votos'}',
            ),
            const SizedBox(height: 16),
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
        );
      },
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
