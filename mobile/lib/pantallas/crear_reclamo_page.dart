import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_exception.dart';
import '../mapa/estilos.dart';
import '../mapa/zona.dart';
import '../modelos/tipo_reclamo.dart';
import '../sesion/sesion.dart';
import '../ubicacion/servicio_ubicacion.dart';
import '../validaciones.dart';
import '../widgets/mensaje_error.dart';

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

  bool _cargandoTipos = true;
  bool _obteniendoUbicacion = false;
  bool _enviando = false;
  String? _error;
  Map<String, String> _erroresDelServer = {};

  @override
  void initState() {
    super.initState();
    _cargarTipos();
    _obtenerUbicacionActual();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarTipos() async {
    try {
      final tipos = await widget.sesion.api.tiposDeReclamo();
      if (mounted) {
        setState(() {
          _tipos = tipos;
          _cargandoTipos = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.mensaje;
          _cargandoTipos = false;
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

  Future<void> _seleccionarImagen(ImageSource origen) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: origen,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() => _imagen = File(pickedFile.path));
    }
  }

  Future<void> _guardarReclamo() async {
    if (_enviando) return;

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
      if (mounted) {
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

  void _mostrarSnackBar(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msj)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Reclamo')),
      body: SafeArea(
        child: _cargandoTipos
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<TipoReclamo>(
                        value: _tipoSeleccionado,
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(
                            _tipoSeleccionado != null
                                ? iconoDeCategoria(_tipoSeleccionado!.icono)
                                : Icons.category_outlined,
                          ),
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
                        onChanged: _enviando
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
                        enabled: !_enviando,
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
                        enabled: !_enviando,
                        maxLines: 3,
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
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _ubicacion == null
                                          ? 'Ubicación no seleccionada'
                                          : 'Lat: ${_ubicacion!.latitude.toStringAsFixed(5)}, Lon: ${_ubicacion!.longitude.toStringAsFixed(5)}',
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.my_location),
                                    onPressed: (_obteniendoUbicacion || _enviando)
                                        ? null
                                        : _obtenerUbicacionActual,
                                  ),
                                ],
                              ),
                              if (_obteniendoUbicacion)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: LinearProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _enviando
                                  ? null
                                  : () => _seleccionarImagen(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Cámara'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _enviando
                                  ? null
                                  : () => _seleccionarImagen(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
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
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            IconButton.filled(
                              icon: const Icon(Icons.close),
                              onPressed: _enviando
                                  ? null
                                  : () => setState(() => _imagen = null),
                            )
                          ],
                        ),
                      ],
                      if (_error case final err?) ...[
                        const SizedBox(height: 16),
                        MensajeError(err),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _enviando ? null : _guardarReclamo,
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