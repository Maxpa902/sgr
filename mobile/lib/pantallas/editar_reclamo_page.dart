import 'dart:io';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_exception.dart';
import '../mapa/estilos.dart';
import '../mapa/zona.dart';
import '../modelos/reclamo_mapa.dart';
import '../sesion/sesion.dart';
import '../ubicacion/servicio_ubicacion.dart';
import '../tema/tema_app.dart';
import '../widgets/componentes_ui.dart';
import '../widgets/formulario_reclamo_ui.dart';
import '../widgets/mensaje_error.dart';

class EditarReclamoPage extends StatefulWidget {
  const EditarReclamoPage({
    super.key,
    required this.reclamo,
    required this.sesion,
    this.ubicacionServicio = const UbicacionDelDispositivo(),
  });

  final ReclamoMapa reclamo;
  final Sesion sesion;
  final ServicioUbicacion ubicacionServicio;

  @override
  State<EditarReclamoPage> createState() => _EditarReclamoPageState();
}

class _EditarReclamoPageState extends State<EditarReclamoPage> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _descripcion;
  late LatLng _ubicacion;

  late List<FotoReclamo> _fotosExistentes;
  final Set<int> _idsFotosEliminar = {};
  final List<File> _nuevasImagenes = [];
  final ImagePicker _picker = ImagePicker();

  bool _obteniendoUbicacion = false;
  bool _enviando = false;
  String? _error;
  Map<String, String> _erroresDelServer = {};

  @override
  void initState() {
    super.initState();
    _titulo = TextEditingController(text: widget.reclamo.titulo);
    _descripcion = TextEditingController(
      text: widget.reclamo.descripcion ?? '',
    );
    _ubicacion = LatLng(widget.reclamo.latitud, widget.reclamo.longitud);
    _fotosExistentes = List<FotoReclamo>.from(widget.reclamo.fotosDetalle);
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  List<FotoReclamo> get _fotosExistentesVisibles =>
      _fotosExistentes.where((f) => !_idsFotosEliminar.contains(f.id)).toList();

  int get _totalFotosActuales =>
      _fotosExistentesVisibles.length + _nuevasImagenes.length;

  bool get _puedeQuitarFoto => _totalFotosActuales > 1;

  bool get _puedeAgregarFoto => _totalFotosActuales < 5;

  Future<void> _obtenerUbicacionActual() async {
    setState(() => _obteniendoUbicacion = true);
    try {
      final punto = await widget.ubicacionServicio.ubicacionActual();
      if (mounted) {
        if (!ZonaDelMapa.limites.contains(punto)) {
          _mostrarSnackBar(
            'Tu ubicación actual está fuera de la zona (${ZonaDelMapa.nombre}).',
          );
        } else {
          setState(() => _ubicacion = punto);
        }
      }
    } on UbicacionException catch (e) {
      if (mounted) _mostrarSnackBar(e.mensaje);
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  Future<void> _seleccionarPuntoEnMapa() async {
    final punto = await showDialog<LatLng>(
      context: context,
      useSafeArea: false,
      builder: (context) => _SelectorPuntoMapaEdicion(puntoInicial: _ubicacion),
    );

    if (punto != null && mounted) {
      setState(() => _ubicacion = punto);
    }
  }

  Future<void> _seleccionarImagen(ImageSource origen) async {
    if (!_puedeAgregarFoto) {
      _mostrarSnackBar('Un reclamo puede tener como máximo 5 fotos.');
      return;
    }

    final XFile? pickedFile = await _picker.pickImage(
      source: origen,
      imageQuality: 80,
    );
    if (pickedFile != null && mounted) {
      setState(() => _nuevasImagenes.add(File(pickedFile.path)));
    }
  }

  Future<void> _guardarCambios() async {
    if (_enviando) return;

    setState(() {
      _error = null;
      _erroresDelServer = {};
    });

    if (!_formulario.currentState!.validate()) return;

    setState(() => _enviando = true);

    try {
      final actualizado = await widget.sesion.editarReclamo(
        id: widget.reclamo.id,
        titulo: _titulo.text.trim(),
        descripcion: _descripcion.text.trim(),
        latitud: _ubicacion.latitude,
        longitud: _ubicacion.longitude,
        fotosEliminar: _idsFotosEliminar.toList(),
        nuevasImagenes: _nuevasImagenes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reclamo actualizado correctamente.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(actualizado);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _erroresDelServer = e.errores;
          _enviando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Ocurrió un error inesperado al actualizar el reclamo.';
          _enviando = false;
        });
      }
    }
  }

  void _mostrarSnackBar(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msj)));
  }

  @override
  Widget build(BuildContext context) {
    final existentesVisibles = _fotosExistentesVisibles;
    return TemaApp(
      child: LayoutPagina(
        titulo: 'Editar Reclamo',
        alVolver: Navigator.of(context).canPop()
            ? () => Navigator.of(context).pop()
            : null,
        superficie: SuperficiePagina.bordeABorde,
        contenido: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DatosFormularioReclamo(
                        categoria: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Categoría (no editable)',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                iconoDeCategoria(widget.reclamo.tipo.icono),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(widget.reclamo.tipo.nombre)),
                            ],
                          ),
                        ),
                        titulo: _titulo,
                        descripcion: _descripcion,
                        habilitado: !_enviando,
                        errores: _erroresDelServer,
                        lineasDescripcion: 3,
                        alCambiarTitulo: (_) =>
                            setState(() => _erroresDelServer.remove('titulo')),
                        alCambiarDescripcion: (_) => setState(
                          () => _erroresDelServer.remove('descripcion'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      UbicacionFormularioReclamo(
                        titulo: 'Ubicación del reclamo',
                        descripcion:
                            'Lat. ${_ubicacion.latitude.toStringAsFixed(5)} · Lon. ${_ubicacion.longitude.toStringAsFixed(5)}',
                        textoMapa: 'Mover punto en el mapa',
                        alElegirMapa: _enviando
                            ? null
                            : _seleccionarPuntoEnMapa,
                        alUsarUbicacion: (_obteniendoUbicacion || _enviando)
                            ? null
                            : _obtenerUbicacionActual,
                        cargando: _obteniendoUbicacion,
                      ),
                      const SizedBox(height: 16),
                      SeccionFormularioReclamo(
                        titulo: 'Fotos del reclamo ($_totalFotosActuales / 5)',
                        icono: Icons.photo_library_outlined,
                        descripcion:
                            'Podés agregar o quitar fotos manteniendo entre 1 y 5.',
                        contenido: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (existentesVisibles.isNotEmpty ||
                                _nuevasImagenes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 120,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final foto in existentesVisibles)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                foto.url,
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      width: 120,
                                                      height: 120,
                                                      color:
                                                          Colors.grey.shade300,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                            if (_puedeQuitarFoto)
                                              IconButton.filled(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                ),
                                                onPressed: _enviando
                                                    ? null
                                                    : () => setState(
                                                        () => _idsFotosEliminar
                                                            .add(foto.id),
                                                      ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    for (
                                      var i = 0;
                                      i < _nuevasImagenes.length;
                                      i++
                                    )
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                _nuevasImagenes[i],
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            if (_puedeQuitarFoto)
                                              IconButton.filled(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                ),
                                                onPressed: _enviando
                                                    ? null
                                                    : () => setState(
                                                        () => _nuevasImagenes
                                                            .removeAt(i),
                                                      ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            BotonesFotoReclamo(
                              alCamara: (_enviando || !_puedeAgregarFoto)
                                  ? null
                                  : () =>
                                        _seleccionarImagen(ImageSource.camera),
                              alGaleria: (_enviando || !_puedeAgregarFoto)
                                  ? null
                                  : () =>
                                        _seleccionarImagen(ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                      if (_error case final err?) ...[
                        const SizedBox(height: 16),
                        MensajeError(err),
                      ],
                      const SizedBox(height: 24),
                      FButton(
                        onPress: _enviando ? null : _guardarCambios,
                        child: _enviando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Guardar cambios'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorPuntoMapaEdicion extends StatefulWidget {
  const _SelectorPuntoMapaEdicion({required this.puntoInicial});

  final LatLng puntoInicial;

  @override
  State<_SelectorPuntoMapaEdicion> createState() =>
      _SelectorPuntoMapaEdicionState();
}

class _SelectorPuntoMapaEdicionState extends State<_SelectorPuntoMapaEdicion> {
  late LatLng _centro = widget.puntoInicial;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Elegir ubicación'),
          leading: IconButton(
            tooltip: 'Cancelar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Text(
                'Mové el mapa hasta que el pin quede sobre el lugar del problema.',
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _centro,
                      initialZoom: ZonaDelMapa.zoomCercano,
                      minZoom: ZonaDelMapa.zoomMinimo,
                      maxZoom: ZonaDelMapa.zoomMaximo,
                      cameraConstraint: CameraConstraint.contain(
                        bounds: ZonaDelMapa.limites,
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture) {
                          setState(() => _centro = camera.center);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ar.sgr.reclamos',
                      ),
                      const SimpleAttributionWidget(
                        source: Text('© OpenStreetMap'),
                        alignment: Alignment.bottomLeft,
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Icon(
                        Icons.location_pin,
                        size: 44,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_centro.latitude.toStringAsFixed(5)}, '
                        '${_centro.longitude.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(_centro),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar punto'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
