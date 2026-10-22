import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_exception.dart';
import '../mapa/barra_filtros.dart';
import '../mapa/estilos.dart';
import '../mapa/pines.dart';
import '../mapa/resumen_reclamo.dart';
import '../mapa/zona.dart';
import '../modelos/reclamo_mapa.dart';
import '../modelos/tipo_reclamo.dart';
import '../sesion/sesion.dart';
import '../ubicacion/servicio_ubicacion.dart';
import '../widgets/mensaje_error.dart';
import 'crear_reclamo_page.dart';
import 'mis_reclamos_page.dart';

/// Contenedor principal con NavigationBar inferior.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({
    super.key,
    required this.sesion,
    this.mostrarMapaBase = true,
  });

  final Sesion sesion;
  final bool mostrarMapaBase;

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceActual,
        children: [
          MapaPage(
            sesion: widget.sesion,
            mostrarMapaBase: widget.mostrarMapaBase,
          ),
          MisReclamosPage(sesion: widget.sesion),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (int index) {
          setState(() => _indiceActual = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Mis Reclamos',
          ),
        ],
      ),
    );
  }
}

/// Pantalla del mapa con los reclamos.
class MapaPage extends StatefulWidget {
  const MapaPage({
    super.key,
    required this.sesion,
    this.ubicacion = const UbicacionDelDispositivo(),
    this.mostrarMapaBase = true,
  });

  final Sesion sesion;
  final ServicioUbicacion ubicacion;
  final bool mostrarMapaBase;

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final _mapa = MapController();

  List<TipoReclamo> _tipos = [];
  List<ReclamoMapa> _reclamos = [];
  Set<String> _estados = {...estadosPorDefecto};
  Set<int>? _tiposElegidos;

  bool _cargando = false;
  String? _error;
  LatLng? _miUbicacion;
  bool _buscandoUbicacion = false;
  int _ultimoPedido = 0;

  @override
  void initState() {
    super.initState();
    _cargarTipos();
    _cargarReclamos();
  }

  @override
  void dispose() {
    _mapa.dispose();
    super.dispose();
  }

  Future<void> _cargarTipos() async {
    try {
      final tipos = await widget.sesion.api.tiposDeReclamo();
      if (mounted) setState(() => _tipos = tipos);
    } on ApiException {
      // Manejo silencioso en el mapa.
    }
  }

  Future<void> _cargarReclamos() async {
    final pedido = ++_ultimoPedido;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final reclamos = await widget.sesion.api.reclamosDelMapa(
        estados: _estados,
        tipos: _tiposElegidos,
      );
      if (mounted && pedido == _ultimoPedido) {
        setState(() => _reclamos = reclamos);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await widget.sesion.cerrarSesion();
        return;
      }
      if (mounted && pedido == _ultimoPedido) {
        setState(() => _error = error.mensaje);
      }
    } finally {
      if (mounted && pedido == _ultimoPedido) {
        setState(() => _cargando = false);
      }
    }
  }

  void _cambiarEstado(String estado) {
    final estados = {..._estados};
    if (!estados.remove(estado)) estados.add(estado);
    if (estados.isEmpty) return;
    setState(() => _estados = estados);
    _cargarReclamos();
  }

  void _cambiarTipo(int tipo) {
    final elegidos = {...(_tiposElegidos ?? _tipos.map((t) => t.id))};
    if (!elegidos.remove(tipo)) elegidos.add(tipo);
    if (elegidos.isEmpty) return;
    setState(() {
      _tiposElegidos = elegidos.length == _tipos.length ? null : elegidos;
    });
    _cargarReclamos();
  }

  void _mostrarResumen(ReclamoMapa reclamo) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ResumenReclamo(reclamo: reclamo),
    );
  }

  Future<void> _irAMiUbicacion() async {
    setState(() => _buscandoUbicacion = true);
    try {
      final punto = await widget.ubicacion.ubicacionActual();
      if (!mounted) return;
      if (!ZonaDelMapa.limites.contains(punto)) {
        _avisar(
          'Tu ubicación está fuera de la zona del mapa (${ZonaDelMapa.nombre}).',
        );
        return;
      }
      setState(() => _miUbicacion = punto);
      _mapa.move(punto, ZonaDelMapa.zoomCercano);
    } on UbicacionException catch (error) {
      _avisar(error.mensaje);
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reclamos'),
        actions: [
          IconButton(
            onPressed: _cargando ? null : _cargarReclamos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          _MenuDeCuenta(sesion: widget.sesion),
        ],
      ),
      body: Stack(
        children: [
          _construirMapa(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 2,
                  child: BarraFiltros(
                    estados: _estados,
                    tipos: _tipos,
                    tiposElegidos: _tiposElegidos,
                    alCambiarEstado: _cambiarEstado,
                    alCambiarTipo: _cambiarTipo,
                  ),
                ),
                if (_cargando) const LinearProgressIndicator(),
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MensajeError(error),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: _cargarReclamos,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                else if (!_cargando && _reclamos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay reclamos con estos filtros.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'crear_reclamo',
            onPressed: () async {
              final creado = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => CrearReclamoPage(sesion: widget.sesion),
                ),
              );
              if (creado == true) {
                _cargarReclamos();
              }
            },
            tooltip: 'Crear Reclamo',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'mi_ubicacion',
            onPressed: _buscandoUbicacion ? null : _irAMiUbicacion,
            tooltip: 'Mi ubicación',
            child: _buscandoUbicacion
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  Widget _construirMapa() {
    return FlutterMap(
      mapController: _mapa,
      options: MapOptions(
        initialCenter: ZonaDelMapa.centroInicial,
        initialZoom: ZonaDelMapa.zoomInicial,
        minZoom: ZonaDelMapa.zoomMinimo,
        maxZoom: ZonaDelMapa.zoomMaximo,
        cameraConstraint: CameraConstraint.contain(bounds: ZonaDelMapa.limites),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        if (widget.mostrarMapaBase)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'ar.sgr.reclamos',
          ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            markers: [
              for (final reclamo in _reclamos)
                Marker(
                  point: LatLng(reclamo.latitud, reclamo.longitud),
                  width: PinReclamo.espacio(reclamo),
                  height: PinReclamo.espacio(reclamo),
                  child: PinReclamo(
                    key: ValueKey('pin-${reclamo.id}'),
                    reclamo: reclamo,
                    alTocar: () => _mostrarResumen(reclamo),
                  ),
                ),
            ],
            markerChildBehavior: true,
            maxClusterRadius: 45,
            size: const Size(46, 46),
            disableClusteringAtZoom: 17,
            showPolygon: false,
            builder: (context, marcadores) =>
                BurbujaDeReclamos(cantidad: marcadores.length),
          ),
        ),
        if (_miUbicacion case final punto?)
          MarkerLayer(
            markers: [
              Marker(
                point: punto,
                width: 36,
                height: 36,
                child: const PuntoMiUbicacion(key: ValueKey('mi-ubicacion')),
              ),
            ],
          ),
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap'),
          alignment: Alignment.bottomLeft,
        ),
      ],
    );
  }
}

class _MenuDeCuenta extends StatelessWidget {
  const _MenuDeCuenta({required this.sesion});

  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    final usuario = sesion.usuario;

    return PopupMenuButton<void>(
      icon: const Icon(Icons.account_circle),
      tooltip: 'Mi cuenta',
      itemBuilder: (_) => [
        if (usuario != null)
          PopupMenuItem<void>(
            enabled: false,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${usuario.nombre} ${usuario.apellido}'),
              subtitle: Text(usuario.rolParaMostrar),
            ),
          ),
        PopupMenuItem<void>(
          onTap: sesion.cerrarSesion,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }
}