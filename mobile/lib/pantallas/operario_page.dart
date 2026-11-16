import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:forui/forui.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_exception.dart';
import '../mapa/estilos.dart';
import '../mapa/pines.dart';
import '../mapa/zona.dart';
import '../modelos/reclamo_admin.dart';
import '../modelos/reclamo_detalle_admin.dart';
import '../sesion/sesion.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/componentes_ui.dart';
import '../widgets/contenido_detalle_reclamo.dart';
import '../widgets/deslizar_para_actualizar.dart';
import 'acciones_reclamo_admin.dart';
import 'cuenta_page.dart';

/// Inicio del personal: trabajo asignado, reclamos disponibles y mapa.
class OperarioPage extends StatefulWidget {
  const OperarioPage({
    super.key,
    required this.sesion,
    this.mostrarMapaBase = true,
  });

  final Sesion sesion;
  final bool mostrarMapaBase;

  @override
  State<OperarioPage> createState() => _OperarioPageState();
}

class _OperarioPageState extends State<OperarioPage> {
  int _seccion = 0;
  _CambioTrabajo? _ultimoCambio;

  Future<void> _abrir(ReclamoAdmin reclamo) async {
    final cambio = await Navigator.of(context).push<_CambioTrabajo>(
      MaterialPageRoute(
        builder: (_) => TemaApp(
          child: _DetalleTrabajo(
            sesion: widget.sesion,
            reclamo: reclamo,
            mostrarMapaBase: widget.mostrarMapaBase,
          ),
        ),
      ),
    );
    if (mounted && cambio != null) {
      setState(() => _ultimoCambio = cambio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinos = const [
      DestinoNavegacion(
        id: 'trabajo',
        etiqueta: 'Trabajo',
        icono: Icons.assignment_outlined,
      ),
      DestinoNavegacion(
        id: 'mapa',
        etiqueta: 'Mapa',
        icono: Icons.map_outlined,
      ),
    ];
    final contenido = switch (_seccion) {
      0 => FTabs(
        expands: true,
        children: [
          FTabEntry(
            label: const Text('Asignados a mí'),
            child: _ListaTrabajo(
              sesion: widget.sesion,
              vista: 'asignados',
              cambio: _ultimoCambio,
              alAbrir: _abrir,
            ),
          ),
          FTabEntry(
            label: const Text('Disponibles'),
            child: _ListaTrabajo(
              sesion: widget.sesion,
              vista: 'disponibles',
              cambio: _ultimoCambio,
              alAbrir: _abrir,
            ),
          ),
        ],
      ),
      _ => _MapaTrabajo(
        sesion: widget.sesion,
        mostrarMapaBase: widget.mostrarMapaBase,
        cambio: _ultimoCambio,
        alAbrir: _abrir,
      ),
    };

    return TemaApp(
      child: LayoutPagina(
        titulo: destinos[_seccion].etiqueta,
        superficie: _seccion == 1
            ? SuperficiePagina.bordeABorde
            : SuperficiePagina.contenido,
        accionesEncabezado: [
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
        pie: BarraNavegacionPrincipal(
          destinos: destinos,
          destinoActual: destinos[_seccion].id,
          alSeleccionar: (id) => setState(() {
            _seccion = destinos.indexWhere((destino) => destino.id == id);
          }),
        ),
        contenido: contenido,
      ),
    );
  }
}

class _ListaTrabajo extends StatefulWidget {
  const _ListaTrabajo({
    required this.sesion,
    required this.vista,
    required this.cambio,
    required this.alAbrir,
  });
  final Sesion sesion;
  final String vista;
  final _CambioTrabajo? cambio;
  final ValueChanged<ReclamoAdmin> alAbrir;

  @override
  State<_ListaTrabajo> createState() => _ListaTrabajoState();
}

class _ListaTrabajoState extends State<_ListaTrabajo> {
  final _scroll = ScrollController();
  final List<ReclamoAdmin> _reclamos = [];
  final Map<int, _CambioTrabajo> _cambiosLocales = {};
  String? _cursor;
  String? _error;
  bool _cargando = false;
  bool _hayMas = true;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazarse);
    unawaited(_recargar());
  }

  @override
  void didUpdateWidget(covariant _ListaTrabajo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cambio = widget.cambio;
    if (cambio == null || identical(cambio, oldWidget.cambio)) return;
    _cambiosLocales[cambio.reclamo.id] = cambio;
    _aplicarCambio(cambio);
  }

  void _aplicarCambio(_CambioTrabajo cambio) {
    final indice = _reclamos.indexWhere((item) => item.id == cambio.reclamo.id);
    final pertenece = cambio.activo && widget.vista == 'asignados';
    _reclamos.removeWhere((item) => item.id == cambio.reclamo.id);
    if (pertenece) {
      final posicion = indice < 0
          ? 0
          : indice > _reclamos.length
          ? _reclamos.length
          : indice;
      _reclamos.insert(posicion, cambio.reclamo);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _alDesplazarse() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
      unawaited(_cargar());
    }
  }

  Future<void> _recargar() async {
    _version++;
    _cambiosLocales.clear();
    setState(() {
      _reclamos.clear();
      _cursor = null;
      _error = null;
      _hayMas = true;
      _cargando = false;
    });
    await _cargar();
  }

  Future<void> _cargar() async {
    if (_cargando || !_hayMas || _error != null) return;
    final version = _version;
    setState(() => _cargando = true);
    try {
      final pagina = await widget.sesion.api.listarTrabajo(
        vista: widget.vista,
        cursor: _cursor,
      );
      if (!mounted || version != _version) return;
      setState(() {
        _reclamos.addAll(pagina.reclamos);
        for (final cambio in _cambiosLocales.values) {
          _aplicarCambio(cambio);
        }
        _cursor = pagina.proximoCursor;
        _hayMas = _cursor != null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scroll.hasClients &&
            _scroll.position.extentAfter < 300) {
          unawaited(_cargar());
        }
      });
    } catch (error) {
      if (mounted && version == _version) {
        setState(
          () => _error = error is ApiException
              ? error.mensaje
              : 'No se pudieron cargar los reclamos.',
        );
      }
    } finally {
      if (mounted && version == _version) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => DeslizarParaActualizar(
    alActualizar: _recargar,
    child: ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          widget.vista == 'asignados'
              ? 'Tus reclamos pendientes y en curso'
              : 'Reclamos pendientes sin responsable',
          style: TextStyle(color: context.theme.colors.mutedForeground),
        ),
        const SizedBox(height: 12),
        for (final reclamo in _reclamos) ...[
          FilaReclamo(
            titulo: reclamo.titulo,
            estado: reclamo.estado,
            iconoCategoria: iconoDeCategoria(reclamo.tipoIcono),
            metadatos: [
              reclamo.tipo,
              if ((reclamo.direccion ?? '').isNotEmpty) reclamo.direccion!,
            ],
            alAbrir: () => widget.alAbrir(reclamo),
          ),
          const SizedBox(height: 8),
        ],
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: FCircularProgress()),
          ),
        if (_error != null && _reclamos.isNotEmpty) ...[
          const SizedBox(height: 12),
          AvisoEnLinea(
            tipo: TipoAviso.error,
            titulo: 'No se pudieron cargar más reclamos',
            mensaje: _error!,
            accion: AccionAviso(
              etiqueta: 'Reintentar',
              alActivar: () {
                setState(() => _error = null);
                unawaited(_cargar());
              },
            ),
          ),
        ],
        if (!_cargando && _error != null && _reclamos.isEmpty)
          SizedBox(
            height: 260,
            child: EstadoContenido(
              tipo: EstadoContenidoTipo.error,
              titulo: 'No pudimos cargar el trabajo',
              descripcion: _error!,
              accion: AccionContenido(
                etiqueta: 'Reintentar',
                alActivar: () {
                  setState(() => _error = null);
                  unawaited(_cargar());
                },
              ),
            ),
          ),
        if (!_cargando && _error == null && _reclamos.isEmpty)
          SizedBox(
            height: 260,
            child: EstadoContenido(
              tipo: EstadoContenidoTipo.vacio,
              titulo: widget.vista == 'asignados'
                  ? 'No tenés reclamos asignados'
                  : 'No hay reclamos disponibles',
              descripcion: widget.vista == 'asignados'
                  ? 'Cuando tomes o recibas un reclamo, aparecerá acá.'
                  : 'Volvé a revisar más tarde.',
            ),
          ),
      ],
    ),
  );
}

class _MapaTrabajo extends StatefulWidget {
  const _MapaTrabajo({
    super.key,
    required this.sesion,
    required this.mostrarMapaBase,
    required this.cambio,
    required this.alAbrir,
  });
  final Sesion sesion;
  final bool mostrarMapaBase;
  final _CambioTrabajo? cambio;
  final ValueChanged<ReclamoAdmin> alAbrir;

  @override
  State<_MapaTrabajo> createState() => _MapaTrabajoState();
}

class _MapaTrabajoState extends State<_MapaTrabajo> {
  late Future<List<ReclamoAdmin>> _futuro;
  final _asignados = <int>{};
  final Map<int, _CambioTrabajo> _cambiosPendientes = {};
  List<ReclamoAdmin>? _reclamos;
  bool _errorMapa = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant _MapaTrabajo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cambio = widget.cambio;
    if (cambio == null || identical(cambio, oldWidget.cambio)) return;
    _cambiosPendientes[cambio.reclamo.id] = cambio;
    final reclamos = _reclamos;
    if (reclamos != null) _aplicarCambioMapa(reclamos, cambio);
  }

  void _aplicarCambioMapa(List<ReclamoAdmin> reclamos, _CambioTrabajo cambio) {
    final indice = reclamos.indexWhere((item) => item.id == cambio.reclamo.id);
    reclamos.removeWhere((item) => item.id == cambio.reclamo.id);
    if (cambio.activo) {
      final posicion = indice < 0
          ? reclamos.length
          : indice > reclamos.length
          ? reclamos.length
          : indice;
      reclamos.insert(posicion, cambio.reclamo);
      _asignados.add(cambio.reclamo.id);
    } else {
      _asignados.remove(cambio.reclamo.id);
    }
  }

  void _cargar() {
    _asignados.clear();
    _errorMapa = false;
    _futuro = _todas();
  }

  Future<List<ReclamoAdmin>> _todas() async {
    final resultado = <ReclamoAdmin>[];
    for (final vista in ['asignados', 'disponibles']) {
      String? cursor;
      final vistos = <String>{};
      do {
        final pagina = await widget.sesion.api.listarTrabajo(
          vista: vista,
          cursor: cursor,
        );
        resultado.addAll(pagina.reclamos);
        if (vista == 'asignados') {
          _asignados.addAll(pagina.reclamos.map((reclamo) => reclamo.id));
        }
        cursor = pagina.proximoCursor;
        if (cursor != null && !vistos.add(cursor)) {
          throw StateError('Cursor repetido');
        }
      } while (cursor != null);
    }
    for (final cambio in _cambiosPendientes.values) {
      _aplicarCambioMapa(resultado, cambio);
    }
    _reclamos = resultado;
    return resultado;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ReclamoAdmin>>(
    future: _futuro,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: FCircularProgress());
      }
      if (snapshot.hasError) {
        return EstadoContenido(
          tipo: EstadoContenidoTipo.error,
          titulo: 'No pudimos cargar el mapa',
          descripcion: snapshot.error is ApiException
              ? (snapshot.error as ApiException).mensaje
              : 'No se pudo cargar el trabajo en el mapa.',
          accion: AccionContenido(
            etiqueta: 'Reintentar',
            alActivar: () => setState(_cargar),
          ),
        );
      }
      final reclamos = snapshot.requireData;
      return Column(
        children: [
          ColoredBox(
            color: ColoresApp.superficie,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reclamos.isEmpty
                          ? 'No hay reclamos asignados ni disponibles.'
                          : '${reclamos.length} reclamos asignados y disponibles',
                    ),
                    if (reclamos.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: ColoresApp.textoSecundario,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Asignado a vos',
                            style: TextStyle(color: ColoresApp.textoSecundario),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: ZonaDelMapa.centroInicial,
                    initialZoom: ZonaDelMapa.zoomInicial,
                    minZoom: ZonaDelMapa.zoomMinimo,
                    maxZoom: ZonaDelMapa.zoomMaximo,
                    cameraConstraint: CameraConstraint.contain(
                      bounds: ZonaDelMapa.limites,
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    if (widget.mostrarMapaBase)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ar.sgr.reclamos',
                        errorTileCallback: (_, _, _) {
                          if (_errorMapa) return;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_errorMapa) {
                              setState(() => _errorMapa = true);
                            }
                          });
                          WidgetsBinding.instance.ensureVisualUpdate();
                        },
                      ),
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        markerChildBehavior: true,
                        maxClusterRadius: 45,
                        size: const Size(46, 46),
                        disableClusteringAtZoom: 17,
                        showPolygon: false,
                        builder: (context, marcadores) =>
                            BurbujaDeReclamos(cantidad: marcadores.length),
                        markers: [
                          for (final reclamo in reclamos)
                            if (reclamo.latitud != null &&
                                reclamo.longitud != null)
                              Marker(
                                point: LatLng(
                                  reclamo.latitud!,
                                  reclamo.longitud!,
                                ),
                                width: 48,
                                height: 48,
                                child: FTappable(
                                  semanticsLabel:
                                      '${reclamo.titulo}, ${nombreDelEstado(reclamo.estado)}',
                                  semanticsButton: true,
                                  onPress: () => widget.alAbrir(reclamo),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: ColoresApp.estadoReclamo(
                                            reclamo.estado,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: ColoresApp.superficie,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          iconoDeCategoria(reclamo.tipoIcono),
                                          color: ColoresApp.superficie,
                                        ),
                                      ),
                                      if (_asignados.contains(reclamo.id))
                                        Positioned(
                                          right: -4,
                                          top: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: ColoresApp.superficie,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: ColoresApp.estadoReclamo(
                                                  reclamo.estado,
                                                ),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              size: 13,
                                              color: ColoresApp.estadoReclamo(
                                                reclamo.estado,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const Align(
                      alignment: Alignment.bottomLeft,
                      child: ColoredBox(
                        color: ColoresApp.superficie,
                        child: Padding(
                          padding: EdgeInsets.all(3),
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(
                              fontSize: 10,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_errorMapa)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: const AvisoEnLinea(
                      tipo: TipoAviso.advertencia,
                      titulo: 'Mapa incompleto',
                      mensaje: 'No se pudieron cargar algunas partes del mapa.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _DetalleTrabajo extends StatefulWidget {
  const _DetalleTrabajo({
    required this.sesion,
    required this.reclamo,
    required this.mostrarMapaBase,
  });
  final Sesion sesion;
  final ReclamoAdmin reclamo;
  int get id => reclamo.id;
  final bool mostrarMapaBase;

  @override
  State<_DetalleTrabajo> createState() => _DetalleTrabajoState();
}

class _DetalleTrabajoState extends State<_DetalleTrabajo> {
  late Future<ReclamoDetalleAdmin> _futuro;
  bool _guardando = false;
  _CambioTrabajo? _cambio;
  ReclamoDetalleAdmin? _detalleAnterior;
  String? _errorAccion;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _futuro = widget.sesion.api.obtenerReclamoTrabajo(widget.id);
  }

  Future<void> _accion({required bool tomar}) async {
    if (_guardando) return;
    setState(() {
      _guardando = true;
      _errorAccion = null;
    });
    try {
      if (tomar) {
        final usuario = widget.sesion.usuario;
        if (usuario == null) throw StateError('Sesión no disponible');
        await widget.sesion.api.asignarReclamo(widget.id, usuario.id);
      } else {
        await widget.sesion.api.comenzarReclamo(widget.id);
      }
      if (mounted) {
        Notificaciones.mostrar(
          context,
          tipo: TipoNotificacion.exito,
          mensaje: tomar ? 'Reclamo asignado' : 'Trabajo iniciado',
        );
        setState(() {
          _cambio = _CambioTrabajo(widget.reclamo, tomar ? 'pendiente' : 'en_proceso');
          _cargar();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorAccion = error is ApiException
              ? error.mensaje
              : 'No se pudo completar la acción.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _abrirCierre({required bool rechazar}) async {
    final cambio = await showFSheet<bool>(
      context: context,
      side: .btt,
      mainAxisMaxRatio: 1,
      resizeToAvoidBottomInset: false,
      barrierDismissible: false,
      draggable: false,
      builder: (_) => Material(
        color: context.theme.colors.card,
        child: rechazar
            ? RechazarReclamoSheet(
                sesion: widget.sesion,
                reclamoId: widget.id,
                soloFalso: true,
              )
            : _FinalizarTrabajoSheet(
                sesion: widget.sesion,
                reclamoId: widget.id,
              ),
      ),
    );
    if (!mounted || cambio != true) return;
    Notificaciones.mostrar(
      context,
      tipo: TipoNotificacion.exito,
      mensaje: rechazar ? 'Reclamo rechazado' : 'Trabajo finalizado',
    );
    setState(() {
      _cambio = _CambioTrabajo(widget.reclamo, rechazar ? 'rechazado' : 'resuelto');
      _cargar();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(_cambio);
    },
    child: LayoutPagina(
      titulo: 'Reclamo #${widget.id}',
      alVolver: () => Navigator.of(context).pop(_cambio),
      superficie: SuperficiePagina.bordeABorde,
      contenido: FutureBuilder<ReclamoDetalleAdmin>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done && _detalleAnterior == null) {
            return const Center(child: FCircularProgress());
          }
          if (snapshot.hasError && _detalleAnterior == null) {
            return EstadoContenido(
              tipo: EstadoContenidoTipo.error,
              titulo: 'No pudimos cargar el reclamo',
              descripcion: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).mensaje
                  : 'Ocurrió un error al consultar el reclamo.',
              accion: AccionContenido(
                etiqueta: 'Reintentar',
                alActivar: () => setState(_cargar),
              ),
            );
          }
          final reclamo = snapshot.data ?? _detalleAnterior!;
          _detalleAnterior = reclamo;
          final actualizando = snapshot.connectionState != ConnectionState.done;
          final responsable = reclamo.responsable;
          final mio =
              responsable != null &&
              responsable.id == widget.sesion.usuario?.id;
          final puedeTomar =
              reclamo.estado == 'pendiente' && responsable == null;
          final puedeComenzar = reclamo.estado == 'pendiente' && mio;
          final asignacion = puedeTomar
              ? 'Disponible para tomar'
              : mio
              ? 'Asignado a vos'
              : responsable != null
              ? 'Responsable: ${responsable.nombreCompleto}'
              : 'Sin responsable';
          return ContenidoDetalleReclamo(
            reclamo: reclamo,
            mostrarMapaBase: widget.mostrarMapaBase,
            responsableTexto: asignacion,
            accionesOperario: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (puedeTomar || puedeComenzar)
                  FButton(
                    onPress: _guardando || actualizando || snapshot.hasError
                        ? null
                        : () => _accion(tomar: puedeTomar),
                    child: Text(
                      _guardando
                          ? 'Guardando…'
                          : (puedeTomar ? 'Tomar reclamo' : 'Comenzar trabajo'),
                    ),
                  ),
                if (reclamo.estado == 'en_proceso' && mio)
                  FButton(
                    onPress: _guardando || actualizando || snapshot.hasError ? null : () => _abrirCierre(rechazar: false),
                    child: const Text('Finalizar trabajo'),
                  ),
                if (mio &&
                    (reclamo.estado == 'pendiente' ||
                        reclamo.estado == 'en_proceso')) ...[
                  const SizedBox(height: 8),
                  FButton(
                    variant: .destructive,
                    onPress: _guardando || actualizando || snapshot.hasError ? null : () => _abrirCierre(rechazar: true),
                    child: const Text('Rechazar por falso'),
                  ),
                ],
                if (snapshot.hasError && _detalleAnterior != null) ...[
                  const SizedBox(height: 12),
                  AvisoEnLinea(
                    tipo: TipoAviso.error,
                    mensaje: 'No se pudo actualizar el reclamo.',
                    accion: AccionAviso(
                      etiqueta: 'Reintentar',
                      alActivar: () => setState(_cargar),
                    ),
                  ),
                ],
                if (_errorAccion != null) ...[
                  const SizedBox(height: 12),
                  AvisoEnLinea(
                    tipo: TipoAviso.error,
                    mensaje: _errorAccion!,
                    accion: AccionAviso(
                      etiqueta: 'Actualizar reclamo',
                      alActivar: () => setState(_cargar),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _FinalizarTrabajoSheet extends StatefulWidget {
  const _FinalizarTrabajoSheet({required this.sesion, required this.reclamoId});
  final Sesion sesion;
  final int reclamoId;
  @override
  State<_FinalizarTrabajoSheet> createState() => _FinalizarTrabajoSheetState();
}

class _FinalizarTrabajoSheetState extends State<_FinalizarTrabajoSheet> {
  final _observacion = TextEditingController();
  bool _interna = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    if (_guardando) return;
    final observacion = _observacion.text.trim();
    if (observacion.isEmpty) {
      setState(() => _error = 'Escribí una observación.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.sesion.api.finalizarReclamo(
        widget.reclamoId,
        observacion: observacion,
        visibilidad: _interna ? 'interna' : 'publica',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.mensaje
            : 'No se pudo finalizar el trabajo.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Finalizar trabajo', style: context.theme.typography.body.lg),
              const SizedBox(height: 12),
              FTextField.multiline(
                control: FTextFieldControl.managed(controller: _observacion),
                enabled: !_guardando,
                minLines: 3,
                maxLines: 5,
                maxLength: 5000,
                label: const Text('Observación'),
              ),
              const SizedBox(height: 16),
              FCheckbox(
                value: _interna,
                enabled: !_guardando,
                onChange: (valor) => setState(() => _interna = valor),
                label: const Text('Observación interna'),
                description: const Text('Si no la marcás, será pública.'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AvisoEnLinea(tipo: TipoAviso.error, mensaje: _error!),
              ],
              const SizedBox(height: 16),
              FButton(
                onPress: _guardando ? null : _finalizar,
                child: Text(_guardando ? 'Finalizando…' : 'Finalizar trabajo'),
              ),
              const SizedBox(height: 8),
              FButton(
                variant: .outline,
                onPress: _guardando ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


class _CambioTrabajo {
  _CambioTrabajo(ReclamoAdmin original, String estado)
    : reclamo = ReclamoAdmin(
        id: original.id,
        titulo: original.titulo,
        tipo: original.tipo,
        estado: estado,
        creador: original.creador,
        emailCreador: original.emailCreador,
        creadoEn: original.creadoEn,
        descripcion: original.descripcion,
        direccion: original.direccion,
        latitud: original.latitud,
        longitud: original.longitud,
        tipoIcono: original.tipoIcono,
        confirmacionesCount: original.confirmacionesCount,
        desmentidasCount: original.desmentidasCount,
      );

  final ReclamoAdmin reclamo;
  bool get activo => reclamo.estado == 'pendiente' || reclamo.estado == 'en_proceso';
}
