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
import '../tema/tema_operario.dart';
import '../widgets/componentes_ui.dart';
import '../widgets/deslizar_para_actualizar.dart';
import 'prueba_componentes_page.dart';

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
  int _revision = 0;
  SuperficiePagina _superficiePrueba = SuperficiePagina.contenido;

  void _cambio() => setState(() => _revision++);

  Future<void> _abrir(ReclamoAdmin reclamo) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TemaOperario(
          child: _DetalleTrabajo(
            sesion: widget.sesion,
            id: reclamo.id,
            mostrarMapaBase: widget.mostrarMapaBase,
          ),
        ),
      ),
    );
    if (mounted && cambio == true) _cambio();
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
      DestinoNavegacion(
        id: 'prueba',
        etiqueta: 'Prueba',
        icono: Icons.widgets_outlined,
      ),
    ];
    final contenido = switch (_seccion) {
      0 => FTabs(
        key: ValueKey('trabajo-$_revision'),
        expands: true,
        children: [
          FTabEntry(
            label: const Text('Asignados a mí'),
            child: _ListaTrabajo(
              sesion: widget.sesion,
              vista: 'asignados',
              alAbrir: _abrir,
            ),
          ),
          FTabEntry(
            label: const Text('Disponibles'),
            child: _ListaTrabajo(
              sesion: widget.sesion,
              vista: 'disponibles',
              alAbrir: _abrir,
            ),
          ),
        ],
      ),
      1 => _MapaTrabajo(
        key: ValueKey('mapa-$_revision'),
        sesion: widget.sesion,
        mostrarMapaBase: widget.mostrarMapaBase,
        alAbrir: _abrir,
      ),
      _ => PruebaComponentesPage(
        superficie: _superficiePrueba,
        alCambiarSuperficie: (superficie) => setState(() {
          _superficiePrueba = superficie;
        }),
      ),
    };

    return TemaOperario(
      child: LayoutPagina(
        titulo: destinos[_seccion].etiqueta,
        superficie: _seccion == 1
            ? SuperficiePagina.bordeABorde
            : _seccion == 2
            ? _superficiePrueba
            : SuperficiePagina.contenido,
        accionesEncabezado: [
          FHeaderAction(
            icon: const Icon(Icons.logout),
            semanticsTooltip: 'Cerrar sesión',
            onPress: () => widget.sesion.cerrarSesion(),
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
    required this.alAbrir,
  });
  final Sesion sesion;
  final String vista;
  final ValueChanged<ReclamoAdmin> alAbrir;

  @override
  State<_ListaTrabajo> createState() => _ListaTrabajoState();
}

class _ListaTrabajoState extends State<_ListaTrabajo> {
  final _scroll = ScrollController();
  final List<ReclamoAdmin> _reclamos = [];
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
    required this.alAbrir,
  });
  final Sesion sesion;
  final bool mostrarMapaBase;
  final ValueChanged<ReclamoAdmin> alAbrir;

  @override
  State<_MapaTrabajo> createState() => _MapaTrabajoState();
}

class _MapaTrabajoState extends State<_MapaTrabajo> {
  late Future<List<ReclamoAdmin>> _futuro;
  final _asignados = <int>{};
  bool _errorMapa = false;

  @override
  void initState() {
    super.initState();
    _cargar();
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
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                            if (reclamo.latitud != null && reclamo.longitud != null)
                              Marker(
                                point: LatLng(reclamo.latitud!, reclamo.longitud!),
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
    required this.id,
    required this.mostrarMapaBase,
  });
  final Sesion sesion;
  final int id;
  final bool mostrarMapaBase;

  @override
  State<_DetalleTrabajo> createState() => _DetalleTrabajoState();
}

class _DetalleTrabajoState extends State<_DetalleTrabajo> {
  late Future<ReclamoDetalleAdmin> _futuro;
  bool _guardando = false;
  bool _cambio = false;
  String? _errorAccion;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _futuro = widget.sesion.api.obtenerReclamoTrabajo(widget.id);
  }

  void _abrirUbicacion(ReclamoDetalleAdmin reclamo) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TemaOperario(
          child: _UbicacionTrabajo(
            titulo: reclamo.titulo,
            punto: LatLng(reclamo.latitud, reclamo.longitud),
            mostrarMapaBase: widget.mostrarMapaBase,
          ),
        ),
      ),
    );
  }

  String _fecha(DateTime fecha, {bool conHora = false}) {
    final local = fecha.toLocal();
    final formato = MaterialLocalizations.of(context);
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final dia = '${local.day} ${meses[local.month - 1]} ${local.year}';
    if (!conHora) return dia;
    final hora = formato.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: true,
    );
    return '$dia · $hora';
  }

  Widget _tituloSeccion(String titulo) => Text(
    titulo,
    style: context.theme.typography.body.md.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _separadorSeccion() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Divider(height: 1, color: context.theme.colors.border),
  );

  Widget _eventoActividad(
    EventoEstadoReclamo evento, {
    required bool ultimo,
    required ResponsableReclamo? responsable,
  }) => Stack(
    children: [
      if (!ultimo)
        Positioned(
          left: 5,
          top: 14,
          bottom: 0,
          child: ExcludeSemantics(
            child: ColoredBox(
              color: context.theme.colors.border,
              child: const SizedBox(width: 2),
            ),
          ),
        ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.theme.colors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: ultimo ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombreDelEstado(evento.estado),
                    style: context.theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_fecha(evento.creadoEn, conHora: true)}'
                    '${evento.autor != null && evento.autor!.id == responsable?.id ? ' · ${evento.autor!.nombreCompleto}' : ''}'
                    '${evento.visibilidad == 'interna' ? ' · Interna' : ''}',
                    style: context.theme.typography.body.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  if (evento.observacion?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(evento.observacion!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );

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
          _cambio = true;
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(_cambio);
    },
    child: LayoutPagina(
      titulo: 'Reclamo #${widget.id}',
      alVolver: () => Navigator.of(context).pop(_cambio),
      contenido: FutureBuilder<ReclamoDetalleAdmin>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: FCircularProgress());
          }
          if (snapshot.hasError) {
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
          final reclamo = snapshot.requireData;
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
          final ubicacionValida =
              reclamo.latitud.isFinite &&
              reclamo.longitud.isFinite &&
              reclamo.latitud.abs() <= 90 &&
              reclamo.longitud.abs() <= 180;
          final eventos = reclamo.historial?.reversed.toList();
          return ListView(
            // El encabezado ya resuelve el área segura superior.
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Text(
                reclamo.titulo,
                style: context.theme.typography.display.xl.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                reclamo.tipo.nombre,
                style: TextStyle(color: context.theme.colors.mutedForeground),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  EstadoReclamoBadge(estado: reclamo.estado),
                  const SizedBox(width: 12),
                  Expanded(child: Text(asignacion)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Creado el ${_fecha(reclamo.creadoEn)}',
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              if (puedeTomar || puedeComenzar) ...[
                const SizedBox(height: 16),
                FButton(
                  onPress: _guardando ? null : () => _accion(tomar: puedeTomar),
                  child: Text(
                    _guardando
                        ? 'Guardando…'
                        : (puedeTomar ? 'Tomar reclamo' : 'Comenzar trabajo'),
                  ),
                ),
              ],
              if (reclamo.estado == 'en_proceso' && mio) ...[
                const SizedBox(height: 8),
                Text(
                  'Finalizar trabajo estará disponible próximamente.',
                  style: TextStyle(color: context.theme.colors.mutedForeground),
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
              _separadorSeccion(),
              _tituloSeccion('Ubicación'),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reclamo.direccion?.isNotEmpty == true
                          ? reclamo.direccion!
                          : ubicacionValida
                          ? 'Ubicación marcada en el mapa'
                          : 'Ubicación no disponible',
                    ),
                  ),
                ],
              ),
              if (ubicacionValida) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FButton(
                    variant: .outline,
                    mainAxisSize: .min,
                    size: .lg,
                    onPress: () => _abrirUbicacion(reclamo),
                    child: const Text('Ver en el mapa'),
                  ),
                ),
              ],
              _separadorSeccion(),
              _tituloSeccion('Descripción'),
              const SizedBox(height: 6),
              Text(
                reclamo.descripcion?.isNotEmpty == true
                    ? reclamo.descripcion!
                    : 'Sin descripción',
              ),
              if (reclamo.fotos.isNotEmpty) ...[
                _separadorSeccion(),
                _tituloSeccion('Fotos'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: reclamo.fotos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        reclamo.fotos[i],
                        width: 230,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 230,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (reclamo.cierre case final cierre?) ...[
                _separadorSeccion(),
                _tituloSeccion('Cierre'),
                const SizedBox(height: 6),
                Text(_fecha(cierre.creadoEn, conHora: true)),
                if (cierre.observacion?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(cierre.observacion!),
                ],
              ],
              _separadorSeccion(),
              _tituloSeccion('Actividad'),
              const SizedBox(height: 12),
              if (eventos == null)
                const Text('El historial de cambios no está disponible.')
              else if (eventos.isEmpty)
                const Text('Sin cambios de estado registrados.')
              else
                for (var i = 0; i < eventos.length; i++)
                  _eventoActividad(
                    eventos[i],
                    ultimo: i == eventos.length - 1,
                    responsable: responsable,
                  ),
            ],
          );
        },
      ),
    ),
  );
}

/// Mapa de consulta centrado en la ubicación del reclamo, sin modificarlo.
class _UbicacionTrabajo extends StatefulWidget {
  const _UbicacionTrabajo({
    required this.titulo,
    required this.punto,
    required this.mostrarMapaBase,
  });

  final String titulo;
  final LatLng punto;
  final bool mostrarMapaBase;

  @override
  State<_UbicacionTrabajo> createState() => _UbicacionTrabajoState();
}

class _UbicacionTrabajoState extends State<_UbicacionTrabajo> {
  bool _errorMapa = false;
  int _revisionMapa = 0;

  void _registrarErrorMapa() {
    if (_errorMapa) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_errorMapa) setState(() => _errorMapa = true);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => LayoutPagina(
    titulo: 'Ubicación',
    alVolver: () => Navigator.of(context).pop(),
    superficie: SuperficiePagina.bordeABorde,
    contenido: Stack(
      children: [
        FlutterMap(
          key: ValueKey(_revisionMapa),
          options: MapOptions(
            initialCenter: widget.punto,
            initialZoom: ZonaDelMapa.zoomCercano,
            minZoom: ZonaDelMapa.zoomMinimo,
            maxZoom: ZonaDelMapa.zoomMaximo,
            backgroundColor: ColoresApp.fondo,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            if (widget.mostrarMapaBase)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ar.sgr.reclamos',
                errorTileCallback: (_, _, _) => _registrarErrorMapa(),
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.punto,
                  width: 48,
                  height: 48,
                  child: Semantics(
                    label: 'Ubicación del reclamo: ${widget.titulo}',
                    image: true,
                    child: const Icon(
                      Icons.location_on,
                      size: 44,
                      color: ColoresApp.principal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (widget.mostrarMapaBase)
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
        if (_errorMapa)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: AvisoEnLinea(
              tipo: TipoAviso.advertencia,
              titulo: 'Mapa incompleto',
              mensaje: 'No se pudieron cargar algunas partes del mapa.',
              accion: AccionAviso(
                etiqueta: 'Reintentar',
                alActivar: () => setState(() {
                  _errorMapa = false;
                  _revisionMapa++;
                }),
              ),
            ),
          ),
      ],
    ),
  );
}
