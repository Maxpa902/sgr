import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../mapa/estilos.dart';
import '../modelos/reclamo_mapa.dart';
import '../sesion/sesion.dart';
import '../tema/tema_app.dart';
import '../widgets/componentes_ui.dart';
import '../widgets/deslizar_para_actualizar.dart';
import 'cuenta_page.dart';
import 'detalle_reclamo_vecino_page.dart';

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

  Future<void> _actualizar() async {
    _reintentar();
    try {
      await _reclamosFuture;
    } catch (_) {
      // FutureBuilder muestra el error y ofrece reintentar.
    }
  }

  Future<void> _mostrarDetalle(ReclamoMapa reclamo) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TemaApp(
          child: DetalleReclamoVecinoPage(
            reclamo: reclamo,
            sesion: widget.sesion,
          ),
        ),
      ),
    );
    if (mounted) _reintentar();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: LayoutPagina(
        titulo: 'Mis reclamos',
        superficie: SuperficiePagina.bordeABorde,
        accionesEncabezado: [
          FHeaderAction(
            onPress: _reintentar,
            icon: const Icon(Icons.refresh),
            semanticsTooltip: 'Actualizar',
          ),
          FHeaderAction(
            icon: const Icon(Icons.account_circle_outlined),
            semanticsTooltip: 'Mi cuenta',
            onPress: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    TemaApp(child: CuentaPage(sesion: widget.sesion)),
              ),
            ),
          ),
        ],
        contenido: Column(
          children: [
            const Material(
              child: TabBar(
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
            Expanded(
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
                    return EstadoContenido(
                      tipo: EstadoContenidoTipo.error,
                      titulo: mensaje,
                      accion: AccionContenido(
                        etiqueta: 'Reintentar',
                        alActivar: _reintentar,
                      ),
                    );
                  }

                  final reclamos = snapshot.data ?? [];
                  final miUsuarioId = widget.sesion.usuario?.id;

                  final misCreados = reclamos
                      .where(
                        (r) =>
                            miUsuarioId != null && r.usuarioId == miUsuarioId,
                      )
                      .toList();

                  final suscritos = reclamos
                      .where(
                        (r) =>
                            miUsuarioId == null || r.usuarioId != miUsuarioId,
                      )
                      .toList();

                  return TabBarView(
                    children: [
                      _ListaReclamosTab(
                        reclamos: misCreados,
                        mensajeVacio: 'Todavía no cargaste ningún reclamo.',
                        iconoVacio: Icons.assignment_outlined,
                        onRefresh: _actualizar,
                        alTocar: _mostrarDetalle,
                        esSuscritos: false,
                      ),
                      _ListaReclamosTab(
                        reclamos: suscritos,
                        mensajeVacio:
                            'No estás suscrito ni votaste reclamos de otros vecinos.',
                        iconoVacio: Icons.how_to_vote_outlined,
                        onRefresh: _actualizar,
                        alTocar: _mostrarDetalle,
                        esSuscritos: true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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
  final Future<void> Function() onRefresh;
  final ValueChanged<ReclamoMapa> alTocar;
  final bool esSuscritos;

  @override
  Widget build(BuildContext context) {
    if (reclamos.isEmpty) {
      return DeslizarParaActualizar(
        alActualizar: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EstadoContenido(
                tipo: EstadoContenidoTipo.vacio,
                titulo: mensajeVacio,
                icono: iconoVacio,
              ),
            ),
          ],
        ),
      );
    }

    return DeslizarParaActualizar(
      alActualizar: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: reclamos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final reclamo = reclamos[index];
          final esAfirmativo = reclamo.miVoto == 'confirma';
          final esDesmentido = reclamo.miVoto == 'desmiente';
          final etiquetaVoto = esSuscritos && (esAfirmativo || esDesmentido)
              ? (esAfirmativo ? 'Confirmaste' : 'Desmentiste')
              : null;

          return FilaReclamo(
            titulo: reclamo.titulo,
            estado: reclamo.estado,
            iconoCategoria: iconoDeCategoria(reclamo.tipo.icono),
            metadatos: [if (etiquetaVoto != null) etiquetaVoto],
            alAbrir: () => alTocar(reclamo),
          );
        },
      ),
    );
  }
}
