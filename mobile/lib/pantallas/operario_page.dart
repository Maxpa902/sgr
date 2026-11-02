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
import '../widgets/deslizar_para_actualizar.dart';

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

  void _cambio() => setState(() => _revision++);

  Future<void> _abrir(ReclamoAdmin reclamo) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _DetalleTrabajo(sesion: widget.sesion, id: reclamo.id),
      ),
    );
    if (mounted && cambio == true) _cambio();
  }

  @override
  Widget build(BuildContext context) => FScaffold(
    childPad: false,
    header: FHeader(
      title: Text(_seccion == 0 ? 'Trabajo' : 'Mapa'),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.logout),
          semanticsTooltip: 'Cerrar sesión',
          onPress: () => widget.sesion.cerrarSesion(),
        ),
      ],
    ),
    footer: FBottomNavigationBar(
      index: _seccion,
      onChange: (index) => setState(() => _seccion = index),
      children: const [
        FBottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          label: Text('Trabajo'),
        ),
        FBottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          label: Text('Mapa'),
        ),
      ],
    ),
    child: _seccion == 0
        ? FTabs(
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
          )
        : _MapaTrabajo(
            key: ValueKey('mapa-$_revision'),
            sesion: widget.sesion,
            mostrarMapaBase: widget.mostrarMapaBase,
            alAbrir: _abrir,
          ),
  );
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
          FTile(
            prefix: Icon(
              iconoDeCategoria(reclamo.tipoIcono),
              color: colorDelEstado(reclamo.estado),
            ),
            title: Text(reclamo.titulo),
            subtitle: Text(
              [
                reclamo.tipo,
                if ((reclamo.direccion ?? '').isNotEmpty) reclamo.direccion!,
              ].join(' · '),
            ),
            suffix: Text(
              nombreDelEstado(reclamo.estado),
              style: TextStyle(color: colorDelEstado(reclamo.estado)),
            ),
            onPress: () => widget.alAbrir(reclamo),
          ),
          const SizedBox(height: 8),
        ],
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: FCircularProgress()),
          ),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: context.theme.colors.error)),
          const SizedBox(height: 8),
          FButton(
            variant: .outline,
            onPress: () {
              setState(() => _error = null);
              unawaited(_cargar());
            },
            child: const Text('Reintentar'),
          ),
        ],
        if (!_cargando && _error == null && _reclamos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                widget.vista == 'asignados'
                    ? 'No tenés reclamos asignados.'
                    : 'No hay reclamos disponibles.',
              ),
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.error is ApiException
                      ? (snapshot.error as ApiException).mensaje
                      : 'No se pudo cargar el mapa.',
                ),
                const SizedBox(height: 12),
                FButton(
                  onPress: () => setState(_cargar),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      }
      final reclamos = snapshot.requireData;
      return Stack(
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
                                    color: colorDelEstado(reclamo.estado),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    iconoDeCategoria(reclamo.tipoIcono),
                                    color: Colors.white,
                                  ),
                                ),
                                if (_asignados.contains(reclamo.id))
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colorDelEstado(reclamo.estado),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        size: 13,
                                        color: colorDelEstado(reclamo.estado),
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
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(3),
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: FCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reclamos.isEmpty
                        ? 'No hay reclamos asignados ni disponibles.'
                        : '${reclamos.length} reclamos asignados y disponibles',
                  ),
                  if (reclamos.isNotEmpty)
                    const Text(
                      'El símbolo de persona indica un reclamo asignado a vos.',
                    ),
                  if (_errorMapa)
                    const Text(
                      'No se pudieron cargar algunas partes del mapa.',
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _DetalleTrabajo extends StatefulWidget {
  const _DetalleTrabajo({required this.sesion, required this.id});
  final Sesion sesion;
  final int id;

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
    child: FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text('Reclamo #${widget.id}'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop(_cambio)),
        ],
      ),
      child: FutureBuilder<ReclamoDetalleAdmin>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: FCircularProgress());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error is ApiException
                          ? (snapshot.error as ApiException).mensaje
                          : 'No se pudo cargar el reclamo.',
                    ),
                    const SizedBox(height: 12),
                    FButton(
                      onPress: () => setState(_cargar),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          final reclamo = snapshot.requireData;
          final mio = reclamo.responsable?.id == widget.sesion.usuario?.id;
          final puedeTomar =
              reclamo.estado == 'pendiente' && reclamo.responsable == null;
          final puedeComenzar = reclamo.estado == 'pendiente' && mio;
          final color = colorDelEstado(reclamo.estado);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                reclamo.tipo.nombre,
                style: TextStyle(color: context.theme.colors.mutedForeground),
              ),
              const SizedBox(height: 8),
              Text(reclamo.titulo, style: context.theme.typography.display.xl),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FBadge(
                  variant: .outline,
                  child: Text(
                    nombreDelEstado(reclamo.estado),
                    style: TextStyle(color: color),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (reclamo.responsable != null)
                Text('Responsable: ${reclamo.responsable!.nombreCompleto}')
              else
                const Text('Sin responsable'),
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
                const SizedBox(height: 16),
                FButton(onPress: null, child: const Text('Finalizar trabajo')),
                const SizedBox(height: 6),
                Text(
                  'Finalizar trabajo estará disponible próximamente.',
                  style: TextStyle(color: context.theme.colors.mutedForeground),
                ),
              ],
              if (_errorAccion != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorAccion!,
                  style: TextStyle(color: context.theme.colors.error),
                ),
                FButton(
                  variant: .ghost,
                  onPress: () => setState(_cargar),
                  child: const Text('Actualizar reclamo'),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Ubicación',
                style: context.theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                reclamo.direccion?.isNotEmpty == true
                    ? reclamo.direccion!
                    : 'Ubicación marcada en el mapa',
              ),
              const SizedBox(height: 24),
              Text(
                'Descripción',
                style: context.theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                reclamo.descripcion?.isNotEmpty == true
                    ? reclamo.descripcion!
                    : 'Sin descripción',
              ),
              if (reclamo.fotos.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Fotos',
                  style: context.theme.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
              const SizedBox(height: 24),
              Text(
                'Seguimiento',
                style: context.theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (reclamo.historial?.isNotEmpty == true)
                for (final evento in reclamo.historial!.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${nombreDelEstado(evento.estado)} · ${evento.autor?.nombreCompleto ?? 'Sistema'}${evento.observacion?.isNotEmpty == true ? '\n${evento.observacion}' : ''}${evento.visibilidad == 'interna' ? ' · Interna' : ''}',
                    ),
                  )
              else
                const Text('Sin cambios de estado registrados.'),
            ],
          );
        },
      ),
    ),
  );
}
