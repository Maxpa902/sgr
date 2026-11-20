import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../tema/colores.dart';
import '../validaciones.dart';

/// Superficie compartida por las secciones de creación y edición.
class SeccionFormularioReclamo extends StatelessWidget {
  const SeccionFormularioReclamo({
    super.key,
    required this.titulo,
    required this.icono,
    required this.contenido,
    this.descripcion,
  });

  final String titulo;
  final IconData icono;
  final String? descripcion;
  final Widget contenido;

  @override
  Widget build(BuildContext context) => FCard(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ColoresApp.principalSuave,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: ColoresApp.principal, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (descripcion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        descripcion!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresApp.textoSecundario,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          contenido,
        ],
      ),
    ),
  );
}

/// Los controladores, errores y acciones permanecen en cada pantalla.
class DatosFormularioReclamo extends StatelessWidget {
  const DatosFormularioReclamo({
    super.key,
    required this.categoria,
    required this.titulo,
    required this.descripcion,
    required this.habilitado,
    required this.errores,
    required this.alCambiarTitulo,
    required this.alCambiarDescripcion,
    this.lineasDescripcion = 1,
  });

  final Widget categoria;
  final TextEditingController titulo;
  final TextEditingController descripcion;
  final bool habilitado;
  final Map<String, String> errores;
  final ValueChanged<String> alCambiarTitulo;
  final ValueChanged<String> alCambiarDescripcion;
  final int lineasDescripcion;

  @override
  Widget build(BuildContext context) => SeccionFormularioReclamo(
    titulo: 'Datos del reclamo',
    icono: Icons.description_outlined,
    contenido: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        categoria,
        const SizedBox(height: 16),
        FTextFormField(
          control: FTextFieldControl.managed(
            controller: titulo,
            onChange: (value) => alCambiarTitulo(value.text),
          ),
          label: const Text('Título'),
          enabled: habilitado,
          validator: obligatorio('Ingresá un título.'),
          forceErrorText: errores['titulo'],
        ),
        const SizedBox(height: 16),
        FTextFormField(
          control: FTextFieldControl.managed(
            controller: descripcion,
            onChange: (value) => alCambiarDescripcion(value.text),
          ),
          label: const Text('Descripción'),
          enabled: habilitado,
          maxLines: lineasDescripcion,
          validator: obligatorio('Ingresá una descripción.'),
          forceErrorText: errores['descripcion'],
        ),
      ],
    ),
  );
}

class UbicacionFormularioReclamo extends StatelessWidget {
  const UbicacionFormularioReclamo({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.textoMapa,
    required this.alElegirMapa,
    required this.alUsarUbicacion,
    required this.cargando,
  });
  final String titulo;
  final String descripcion;
  final String textoMapa;
  final VoidCallback? alElegirMapa;
  final VoidCallback? alUsarUbicacion;
  final bool cargando;

  @override
  Widget build(BuildContext context) => SeccionFormularioReclamo(
    titulo: titulo,
    icono: Icons.location_on_outlined,
    descripcion: descripcion,
    contenido: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FButton(
          variant: .outline,
          onPress: alElegirMapa,
          prefix: const Icon(Icons.map_outlined),
          child: Text(textoMapa),
        ),
        const SizedBox(height: 8),
        FButton(
          variant: .ghost,
          onPress: alUsarUbicacion,
          prefix: const Icon(Icons.my_location),
          child: const Text('Usar mi ubicación actual'),
        ),
        if (cargando) const LinearProgressIndicator(),
      ],
    ),
  );
}

class BotonesFotoReclamo extends StatelessWidget {
  const BotonesFotoReclamo({
    super.key,
    required this.alCamara,
    required this.alGaleria,
  });
  final VoidCallback? alCamara;
  final VoidCallback? alGaleria;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final camara = FButton(
        variant: .outline,
        onPress: alCamara,
        prefix: const Icon(Icons.camera_alt_outlined),
        child: const Text('Cámara'),
      );
      final galeria = FButton(
        variant: .outline,
        onPress: alGaleria,
        prefix: const Icon(Icons.photo_library_outlined),
        child: const Text('Galería'),
      );
      if (constraints.maxWidth < 290 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.25) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [camara, const SizedBox(height: 8), galeria],
        );
      }
      return Row(
        children: [
          Expanded(child: camara),
          const SizedBox(width: 12),
          Expanded(child: galeria),
        ],
      );
    },
  );
}
