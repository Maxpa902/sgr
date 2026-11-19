import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../modelos/reclamo_detalle_admin.dart';
import '../sesion/sesion.dart';
import '../widgets/deslizar_para_actualizar.dart';
import '../widgets/componentes_ui.dart';
import '../widgets/contenido_detalle_reclamo.dart';
import 'acciones_reclamo_admin.dart';
import '../widgets/lista_votantes_sheet.dart';

class DetalleReclamoAdminPage extends StatefulWidget {
  const DetalleReclamoAdminPage({
    super.key,
    required this.sesion,
    required this.reclamoId,
    this.alCambiar,
    this.mostrarMapaBase = true,
  });

  final Sesion sesion;
  final int reclamoId;
  final VoidCallback? alCambiar;
  final bool mostrarMapaBase;

  @override
  State<DetalleReclamoAdminPage> createState() =>
      _DetalleReclamoAdminPageState();
}

class _DetalleReclamoAdminPageState extends State<DetalleReclamoAdminPage> {
  late Future<ReclamoDetalleAdmin> _detalle;
  bool _ocupado = false;
  int _versionConsulta = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _versionConsulta++;
    _detalle = widget.sesion.obtenerReclamoAdmin(widget.reclamoId);
  }

  void _reintentar() => setState(_cargar);

  Future<void> _actualizarManualmente() async {
    final version = ++_versionConsulta;
    try {
      final detalle = await widget.sesion.obtenerReclamoAdmin(widget.reclamoId);
      if (!mounted || version != _versionConsulta) return;
      setState(() {
        _detalle = Future.value(detalle);
      });
      widget.alCambiar?.call();
    } on ApiException catch (error) {
      if (mounted && version == _versionConsulta) _mostrarError(error.mensaje);
    } catch (_) {
      if (mounted && version == _versionConsulta) {
        _mostrarError('No se pudo actualizar el reclamo.');
      }
    }
  }

  void _actualizarTrasCambio() {
    widget.alCambiar?.call();
    _reintentar();
  }

  Future<void> _asignar() async {
    final cambio = await showFSheet<bool>(
      context: context,
      side: .btt,
      mainAxisMaxRatio: 1,
      resizeToAvoidBottomInset: false,
      barrierDismissible: false,
      draggable: false,
      builder: (_) => _SuperficiePanel(
        child: SelectorResponsableSheet(
          sesion: widget.sesion,
          reclamoId: widget.reclamoId,
        ),
      ),
    );
    if (mounted && cambio == true) _actualizarTrasCambio();
  }

  Future<void> _rechazar() async {
    final cambio = await showFSheet<bool>(
      context: context,
      side: .btt,
      mainAxisMaxRatio: 1,
      resizeToAvoidBottomInset: false,
      barrierDismissible: false,
      draggable: false,
      builder: (_) => _SuperficiePanel(
        child: RechazarReclamoSheet(
          sesion: widget.sesion,
          reclamoId: widget.reclamoId,
        ),
      ),
    );
    if (mounted && cambio == true) _actualizarTrasCambio();
  }

  Future<void> _desasignar() async {
    if (_ocupado) return;
    final confirmado = await showFDialog<bool>(
      context: context,
      builder: (context, _, animation) => FDialog(
        animation: animation,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Quitar responsable?',
                style: context.theme.typography.body.lg,
              ),
              const SizedBox(height: 12),
              const Text('El reclamo quedará pendiente y sin responsable.'),
              const SizedBox(height: 20),
              FButton(
                variant: .destructive,
                onPress: () => Navigator.pop(context, true),
                child: const Text('Desasignar'),
              ),
              const SizedBox(height: 8),
              FButton(
                variant: .outline,
                onPress: () => Navigator.pop(context, false),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await widget.sesion.api.desasignarReclamo(widget.reclamoId);
      if (mounted) _actualizarTrasCambio();
    } on ApiException catch (error) {
      if (mounted) {
        _mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        _mostrarError('No se pudo desasignar el reclamo.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _mostrarError(String mensaje) {
    showFDialog<void>(
      context: context,
      builder: (context, _, animation) => FDialog(
        animation: animation,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mensaje),
              const SizedBox(height: 16),
              FButton(
                onPress: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutPagina(
    titulo: 'Reclamo #${widget.reclamoId}',
    alVolver: () => Navigator.of(context).pop(),
    superficie: SuperficiePagina.bordeABorde,
    contenido: FutureBuilder<ReclamoDetalleAdmin>(
      future: _detalle,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: FCircularProgress());
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final mensaje = error is ApiException
              ? error.mensaje
              : 'No se pudo cargar el reclamo.';
          return DeslizarParaActualizar(
            alActualizar: _actualizarManualmente,
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 40),
                            const SizedBox(height: 12),
                            Text(mensaje, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FButton(
                              onPress: _reintentar,
                              prefix: const Icon(Icons.refresh),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return DeslizarParaActualizar(
          alActualizar: _actualizarManualmente,
          child: ContenidoDetalleReclamo(
            esAdmin: true,
            reclamo: snapshot.requireData,
            ocupado: _ocupado,
            alAsignar: _asignar,
            alDesasignar: _desasignar,
            alRechazar: _rechazar,

            alVerVotantes: () => ListaVotantesSheet.mostrar(
              context,
              sesion: widget.sesion,
              reclamoId: widget.reclamoId,
            ),

            mostrarMapaBase: widget.mostrarMapaBase,
          ),
        );
      },
    ),
  );
}

/// Superficie opaca para el contenido de las hojas modales de Forui.
class _SuperficiePanel extends StatelessWidget {
  const _SuperficiePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    child: ColoredBox(
      key: const ValueKey('superficie-panel-reclamo'),
      color: context.theme.colors.background,
      child: Padding(padding: const EdgeInsets.only(top: 16), child: child),
    ),
  );
}
