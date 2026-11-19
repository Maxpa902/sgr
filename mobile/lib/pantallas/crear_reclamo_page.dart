import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../formato.dart';

import '../api/api_exception.dart';
import '../mapa/estilos.dart';
import '../mapa/zona.dart';
import '../modelos/tipo_reclamo.dart';
import '../sesion/sesion.dart';
import '../ubicacion/servicio_ubicacion.dart';
import '../validaciones.dart';
import '../widgets/mensaje_error.dart';
import '../mapa/resumen_reclamo.dart';
import '../modelos/reclamo_mapa.dart';


class CrearReclamoPage extends StatefulWidget {
  const CrearReclamoPage({
    super.key,
    required this.sesion,
    this.ubicacionServicio = const UbicacionDelDispositivo(),
  });

  final Sesion sesion;
  final ServicioUbicacion ubicacionServicio;

  @override
  State<CrearReclamoPage> createState() => _CrearReclamoPageState();
}

class _CrearReclamoPageState extends State<CrearReclamoPage> {
  final _formulario = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();

  List<TipoReclamo> _tipos = [];
  TipoReclamo? _tipoSeleccionado;

  LatLng? _ubicacion;
  File? _imagen;
  final ImagePicker _picker = ImagePicker();

  bool _cargandoDatos = true;
  bool _obteniendoUbicacion = false;
  bool _enviando = false;
  String? _error;
  Map<String, String> _erroresDelServer = {};

  int _cantidadReclamosActivos = 0;


  bool get _alcanzoLimiteReclamos => _cantidadReclamosActivos >= 3;

  bool get _estaSuspendido {
    final usuario = widget.sesion.usuario;
    return usuario != null && usuario.estaSuspendido;
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final resultados = await Future.wait([
        widget.sesion.api.tiposDeReclamo(),
        widget.sesion.misReclamos(),
      ]);

      final tipos = resultados[0] as List<TipoReclamo>;
      final misReclamos = resultados[1] as List<ReclamoMapa>;

      final miUsuarioId = widget.sesion.usuario?.id;

      final activos = misReclamos.where((r) {
        final esCreadoPorMi = r.usuarioId == miUsuarioId;
        final estaActivo = r.estado == 'pendiente' || r.estado == 'en_proceso';
        return esCreadoPorMi && estaActivo;
      }).length;

      if (mounted) {
        setState(() {
          _tipos = tipos;
          _cantidadReclamosActivos = activos;
          _cargandoDatos = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.mensaje;
          _cargandoDatos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ocurrió un error al cargar la información inicial.';
          _cargandoDatos = false;
        });
      }
    }
  }

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
      builder: (context) => _SelectorPuntoMapa(
        puntoInicial: _ubicacion,
      ),
    );

    if (punto != null && mounted) {
      setState(() => _ubicacion = punto);
    }
  }

  Future<void> _seleccionarImagen(ImageSource origen) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: origen,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() => _imagen = File(pickedFile.path));
    }
  }

  Future<void> _guardarReclamo({bool forzarCreacion = false}) async {
    if (_enviando || _alcanzoLimiteReclamos) return;

    setState(() {
      _error = null;
      _erroresDelServer = {};
    });

    if (!_formulario.currentState!.validate()) return;

    if (_ubicacion == null) {
      setState(() => _error = 'Debes especificar la ubicación del reclamo.');
      return;
    }

    setState(() => _enviando = true);

    try {
      await widget.sesion.crearReclamo(
        titulo: _titulo.text.trim(),
        descripcion: _descripcion.text.trim(),
        tipoId: _tipoSeleccionado!.id,
        latitud: _ubicacion!.latitude,
        longitud: _ubicacion!.longitude,
        imagen: _imagen,
        forzarCreacion: forzarCreacion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reclamo creado con éxito.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          _formulario.currentState!.reset();
          setState(() {
            _titulo.clear();
            _descripcion.clear();
            _tipoSeleccionado = null;
            _imagen = null;
            _enviando = false;
          });
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.reclamoDuplicado != null) {
        setState(() => _enviando = false);
        _mostrarDialogoDuplicado(e.reclamoDuplicado!);
      } else {
        setState(() {
          _error = e.mensaje;
          _erroresDelServer = e.errores;
          _enviando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ocurrió un error inesperado al guardar.';
          _enviando = false;
        });
      }
    }
  }

  void _mostrarDialogoDuplicado(ReclamoMapa duplicado) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¿Es el mismo reclamo?',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Existe un reporte activo de la misma categoría a menos de 50 metros:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      duplicado.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (duplicado.descripcion != null &&
                        duplicado.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        duplicado.descripcion!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (duplicado.direccion != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              duplicado.direccion!,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 16, thickness: 0.8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cargado ${haceCuanto(duplicado.creadoEn)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.thumb_up_alt_outlined,
                              size: 14,
                              color: Colors.green.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${duplicado.confirmaciones} confirmaciones',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _guardarReclamo(forzarCreacion: true);
              },
              child: const Text('No, es otro problema'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => ResumenReclamo(
                    reclamo: duplicado,
                    sesion: widget.sesion,
                  ),
                );
              },
              child: const Text('Ver reclamo existente'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarSnackBar(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msj)));
  }

  @override
  Widget build(BuildContext context) {
    final bool suspendido = _estaSuspendido;
    final bool deshabilitado = _enviando || _alcanzoLimiteReclamos || suspendido;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Reclamo')),
      body: SafeArea(
        child: _cargandoDatos
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. AVISO SI ESTÁ SUSPENDIDO POR SANCIONES
                      if (suspendido) ...[
                        Card(
                          color: Colors.red.shade50,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.red.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.block,
                                  color: Colors.red.shade900,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tu cuenta está suspendida temporalmente para crear reclamos debido a reportes falsos. Podrás volver a publicar más adelante.',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_alcanzoLimiteReclamos) ...[
                        Card(
                          color: Colors.amber.shade50,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.amber.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.amber.shade900,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Alcanzaste el límite de 3 reclamos activos. Esperá a que se resuelvan para crear uno nuevo.',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      DropdownButtonFormField<TipoReclamo>(
                        value: _tipoSeleccionado,
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          border: const OutlineInputBorder(),
                          errorText: _erroresDelServer['tipo_id'],
                        ),
                        items: _tipos
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      Icon(iconoDeCategoria(t.icono), size: 20),
                                      const SizedBox(width: 8),
                                      Text(t.nombre),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: deshabilitado
                            ? null
                            : (val) => setState(() {
                                  _tipoSeleccionado = val;
                                  _erroresDelServer.remove('tipo_id');
                                }),
                        validator: (v) =>
                            v == null ? 'Seleccioná un tipo de reclamo.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titulo,
                        enabled: !deshabilitado,
                        decoration: InputDecoration(
                          labelText: 'Título',
                          prefixIcon: const Icon(Icons.title_outlined),
                          border: const OutlineInputBorder(),
                          errorText: _erroresDelServer['titulo'],
                        ),
                        validator: obligatorio('Ingresá un título.'),
                        onChanged: (_) =>
                            setState(() => _erroresDelServer.remove('titulo')),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descripcion,
                        enabled: !deshabilitado,
                        decoration: InputDecoration(
                          labelText: 'Descripción',
                          prefixIcon: const Icon(Icons.description_outlined),
                          border: const OutlineInputBorder(),
                          errorText: _erroresDelServer['descripcion'],
                        ),
                        validator: obligatorio('Ingresá una descripción.'),
                        onChanged: (_) => setState(
                            () => _erroresDelServer.remove('descripcion')),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _ubicacion == null
                                              ? 'Elegí dónde ocurre el problema'
                                              : 'Punto seleccionado',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _ubicacion == null
                                              ? 'Podés marcarlo en el mapa sin compartir tu ubicación.'
                                              : 'Lat. ${_ubicacion!.latitude.toStringAsFixed(5)} · Lon. ${_ubicacion!.longitude.toStringAsFixed(5)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: deshabilitado
                                    ? null
                                    : _seleccionarPuntoEnMapa,
                                icon: const Icon(Icons.map_outlined),
                                label: Text(
                                  _ubicacion == null
                                      ? 'Elegir punto en el mapa'
                                      : 'Mover punto en el mapa',
                                ),
                              ),
                              TextButton.icon(
                                onPressed:
                                    (_obteniendoUbicacion || deshabilitado)
                                        ? null
                                        : _obtenerUbicacionActual,
                                icon: const Icon(Icons.my_location),
                                label: const Text('Usar mi ubicación actual'),
                              ),
                              if (_obteniendoUbicacion)
                                const LinearProgressIndicator(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.add_a_photo_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Adjuntar evidencia fotográfica',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Podés tomar una foto o elegir una de tu galería (opcional).',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: deshabilitado
                                          ? null
                                          : () => _seleccionarImagen(
                                                ImageSource.camera,
                                              ),
                                      icon: const Icon(
                                        Icons.camera_alt_outlined,
                                      ),
                                      label: const Text('Cámara'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: deshabilitado
                                          ? null
                                          : () => _seleccionarImagen(
                                                ImageSource.gallery,
                                              ),
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                      ),
                                      label: const Text('Galería'),
                                    ),
                                  ),
                                ],
                              ),
                              if (_imagen != null) ...[
                                const SizedBox(height: 12),
                                Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _imagen!,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    IconButton.filled(
                                      icon: const Icon(Icons.close),
                                      onPressed: deshabilitado
                                          ? null
                                          : () =>
                                              setState(() => _imagen = null),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_error case final err?) ...[
                        const SizedBox(height: 16),
                        MensajeError(err),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: deshabilitado ? null : _guardarReclamo,
                        child: _enviando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Enviar Reclamo'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _SelectorPuntoMapa extends StatefulWidget {
  const _SelectorPuntoMapa({this.puntoInicial});

  final LatLng? puntoInicial;

  @override
  State<_SelectorPuntoMapa> createState() => _SelectorPuntoMapaState();
}

class _SelectorPuntoMapaState extends State<_SelectorPuntoMapa> {
  late LatLng _centro = widget.puntoInicial ?? ZonaDelMapa.centroInicial;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: StatefulBuilder(
        builder: (context, actualizarDialogo) => Scaffold(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                        initialZoom: ZonaDelMapa.zoomInicial,
                        minZoom: ZonaDelMapa.zoomMinimo,
                        maxZoom: ZonaDelMapa.zoomMaximo,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: ZonaDelMapa.limites,
                        ),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all &
                              ~InteractiveFlag.rotate,
                        ),
                        onPositionChanged: (camera, hasGesture) {
                          if (hasGesture) {
                            actualizarDialogo(() => _centro = camera.center);
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
      ),
    );
  }
}
