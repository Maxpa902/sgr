import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../formato.dart';
import '../mapa/estilos.dart';
import '../modelos/reclamo_mapa.dart';
import '../sesion/sesion.dart';
import '../tema/tema_app.dart';
import '../tema/colores.dart';
import '../widgets/comentarios_reclamo.dart';
import '../widgets/componentes_ui.dart';
import '../widgets/lista_votantes_sheet.dart';
import '../widgets/seguimiento_reclamo.dart';
import 'editar_reclamo_page.dart';

/// Detalle público de un reclamo, tanto propio como de otro vecino.
class DetalleReclamoVecinoPage extends StatefulWidget {
  const DetalleReclamoVecinoPage({
    super.key,
    required this.reclamo,
    required this.sesion,
    this.alCambiar,
  });
  final ReclamoMapa reclamo;
  final Sesion sesion;
  final VoidCallback? alCambiar;

  @override
  State<DetalleReclamoVecinoPage> createState() =>
      _DetalleReclamoVecinoPageState();
}

class _DetalleReclamoVecinoPageState extends State<DetalleReclamoVecinoPage> {
  DetalleReclamoVecino? _detalle;
  bool _cargando = true;
  bool _ocupado = false;
  String? _error;
  BuildContext? _contextoNotificaciones;

  void _notificar(String mensaje, {bool error = false}) {
    final contexto = _contextoNotificaciones;
    if (mounted && contexto != null && contexto.mounted) {
      Notificaciones.mostrar(
        contexto,
        tipo: error ? TipoNotificacion.error : TipoNotificacion.exito,
        mensaje: mensaje,
        id: this,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await widget.sesion.api.detalleReclamoVecino(
        widget.reclamo.id,
      );
      if (mounted) {
        setState(() {
          _detalle = detalle;
          _cargando = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.statusCode == 404
              ? 'Este reclamo ya no está disponible.'
              : e.mensaje;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el reclamo.';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _votar(String valor) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
    });
    try {
      final retirado = _detalle?.reclamo.miVoto == valor;
      await widget.sesion.votarReclamo(widget.reclamo.id, valor);
      widget.alCambiar?.call();
      _notificar(
        retirado
            ? 'Quitaste tu voto.'
            : valor == 'confirma'
            ? 'Confirmaste este reclamo.'
            : 'Desmentiste este reclamo.',
      );
    } on ApiException catch (e) {
      _notificar(e.mensaje, error: true);
    } catch (_) {
      _notificar('No se pudo registrar tu voto.', error: true);
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
        await _cargar();
      }
    }
  }

  Future<void> _editar() async {
    final actual = _detalle?.reclamo;
    if (actual == null) return;
    final resultado = await Navigator.of(context).push<ReclamoMapa>(
      MaterialPageRoute(
        builder: (_) => TemaApp(
          child: EditarReclamoPage(reclamo: actual, sesion: widget.sesion),
        ),
      ),
    );
    if (resultado != null && mounted) {
      widget.alCambiar?.call();
      _notificar('Reclamo actualizado correctamente.');
      await _cargar();
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Dar de baja este reclamo?',
      descripcion:
          'El reclamo dejará de mostrarse en el mapa. Esta acción no se puede deshacer.',
      textoConfirmar: 'Sí, dar de baja',
      variante: TipoConfirmacionAccion.destructiva,
    );
    if (!confirmado || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await widget.sesion.eliminarReclamo(widget.reclamo.id);
      widget.alCambiar?.call();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        _notificar(e.mensaje, error: true);
        await _cargar();
      }
    } catch (_) {
      if (mounted) {
        _notificar('No se pudo dar de baja el reclamo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => TemaApp(
    child: Builder(
      builder: (context) {
        _contextoNotificaciones = context;
        final detalle = _detalle;
        final reclamo = detalle?.reclamo ?? widget.reclamo;
        final propio = reclamo.usuarioId == widget.sesion.usuario?.id;
        return LayoutPagina(
          titulo: '',
          alVolver: () => Navigator.of(context).pop(),
          superficie: SuperficiePagina.bordeABorde,
          accionesEncabezado: [
            FHeaderAction(
              icon: const Icon(Icons.refresh),
              semanticsTooltip: 'Actualizar',
              onPress: _cargar,
            ),
          ],
          contenido: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reclamo.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        EstadoReclamoBadge(estado: reclamo.estado),
                        Text(
                          'Cargado ${haceCuanto(reclamo.creadoEn)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ColoresApp.textoSecundario),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: Text(_error!)),
                      TextButton(
                        onPressed: _cargar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              if (_cargando && detalle == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (detalle == null)
                const Expanded(child: SizedBox())
              else
                Expanded(
                  child: FTabs(
                    expands: true,
                    scrollable: true,
                    contentPhysics: const NeverScrollableScrollPhysics(),
                    onPress: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    children: [
                      FTabEntry(
                        label: const Text('Detalle', maxLines: 1),
                        child: _Mantener(
                          child: _contenidoDetalle(context, detalle, propio),
                        ),
                      ),
                      FTabEntry(
                        label: const Text('Seguimiento', maxLines: 1),
                        child: _Mantener(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              _Superficie(
                                child: SeguimientoReclamo(
                                  sesion: widget.sesion,
                                  reclamoId: reclamo.id,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      FTabEntry(
                        label: const Text('Comentarios', maxLines: 1),
                        child: _Mantener(
                          child: ComentariosReclamo(
                            sesion: widget.sesion,
                            reclamoId: reclamo.id,
                            pantallaCompleta: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _contenidoDetalle(
    BuildContext context,
    DetalleReclamoVecino detalle,
    bool propio,
  ) {
    final r = detalle.reclamo;
    final habilitado = !_ocupado && !_cargando && _error == null;
    final textos = Theme.of(context).textTheme;
    final direccion = r.direccion?.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        if (propio) ...[
          Text(
            'Tu reclamo',
            style: textos.labelLarge?.copyWith(color: ColoresApp.secundario),
          ),
          const SizedBox(height: 10),
        ],
        _Superficie(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ColoresApp.principalSuave,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconoDeCategoria(r.tipo.icono),
                      color: ColoresApp.principal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.tipo.nombre,
                          style: textos.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ColoresApp.textoPrincipal,
                          ),
                        ),
                        if (direccion != null && direccion.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            direccion,
                            style: textos.bodyMedium?.copyWith(
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (r.descripcion != null &&
                  r.descripcion!.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Descripción',
                  style: textos.labelLarge?.copyWith(
                    color: ColoresApp.textoSecundario,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  r.descripcion!,
                  style: textos.bodyMedium?.copyWith(
                    height: 1.5,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
              ],
              if (r.fotos.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: r.fotos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        r.fotos[i],
                        width: 240,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 140,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Superficie(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Participación de vecinos',
                style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                '¿Coincidís con este reclamo?',
                style: textos.bodySmall?.copyWith(
                  color: ColoresApp.textoSecundario,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final estrecho =
                      constraints.maxWidth < 320 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.2;
                  final confirmar = _botonVoto(
                    valor: 'confirma',
                    texto: 'Confirmar (${r.confirmaciones})',
                    seleccionado: r.miVoto == 'confirma',
                    habilitado: habilitado && detalle.puedeVotar,
                  );
                  final desmentir = _botonVoto(
                    valor: 'desmiente',
                    texto: 'Desmentir (${r.desmentidas})',
                    seleccionado: r.miVoto == 'desmiente',
                    habilitado: habilitado && detalle.puedeVotar,
                  );
                  if (estrecho) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        confirmar,
                        const SizedBox(height: 8),
                        desmentir,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: confirmar),
                      const SizedBox(width: 8),
                      Expanded(child: desmentir),
                    ],
                  );
                },
              ),
              if (r.miVoto != null && detalle.puedeVotar) ...[
                const SizedBox(height: 8),
                Text(
                  'Tu voto está seleccionado. Tocá nuevamente para quitarlo.',
                  style: textos.bodySmall?.copyWith(
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ],
              if (!detalle.puedeVotar) ...[
                const SizedBox(height: 8),
                Text(
                  propio
                      ? 'No podés votar tu propio reclamo.'
                      : 'No podés votar este reclamo en este momento.',
                  style: textos.bodySmall?.copyWith(
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ],
              if (r.confirmaciones + r.desmentidas > 0) ...[
                const SizedBox(height: 8),
                FButton(
                  variant: .ghost,
                  size: .sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => ListaVotantesSheet.mostrar(
                    context,
                    sesion: widget.sesion,
                    reclamoId: r.id,
                  ),
                  prefix: const Icon(
                    Icons.people_outline,
                    color: ColoresApp.principal,
                  ),
                  child: const Flexible(
                    child: Text(
                      'Ver lista de votantes',
                      style: TextStyle(color: ColoresApp.principal),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (propio && (detalle.puedeEditar || detalle.puedeEliminar)) ...[
          const SizedBox(height: 16),
          if (detalle.puedeEditar)
            FButton(
              variant: .outline,
              onPress: habilitado ? _editar : null,
              prefix: const Icon(Icons.edit_outlined),
              child: const Text('Editar reclamo'),
            ),
          if (detalle.puedeEditar && detalle.puedeEliminar)
            const SizedBox(height: 8),
          if (detalle.puedeEliminar)
            FButton(
              variant: .destructive,
              onPress: habilitado ? _eliminar : null,
              prefix: const Icon(Icons.delete_outline),
              child: const Text('Dar de baja'),
            ),
        ],
      ],
    );
  }

  Widget _botonVoto({
    required String valor,
    required String texto,
    required bool seleccionado,
    required bool habilitado,
  }) {
    final color = valor == 'confirma' ? ColoresApp.exito : ColoresApp.error;
    final fondo = valor == 'confirma'
        ? ColoresApp.exitoFondo
        : ColoresApp.errorFondo;
    final visible = habilitado ? color : ColoresApp.textoSecundario;
    return Semantics(
      selected: seleccionado,
      child: FButton(
        variant: .outline,
        style: FButtonStyleDelta.delta(
          decoration: FVariantsDelta.delta([
            FVariantOperation.all(
              DecorationDelta.shapeDelta(
                color: seleccionado && habilitado
                    ? fondo
                    : ColoresApp.superficie,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: habilitado ? color : ColoresApp.borde,
                    width: seleccionado ? 2 : 1,
                  ),
                ),
              ),
            ),
          ]),
        ),
        onPress: habilitado ? () => _votar(valor) : null,
        prefix: Icon(
          valor == 'confirma'
              ? (seleccionado ? Icons.thumb_up : Icons.thumb_up_outlined)
              : (seleccionado ? Icons.thumb_down : Icons.thumb_down_outlined),
          color: visible,
        ),
        child: Flexible(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: visible,
              fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Superficie extends StatelessWidget {
  const _Superficie({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => FCard(
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class _Mantener extends StatefulWidget {
  const _Mantener({required this.child});
  final Widget child;
  @override
  State<_Mantener> createState() => _MantenerState();
}

class _MantenerState extends State<_Mantener>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
