import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../widgets/componentes_ui.dart';

/// Catálogo manual de los componentes comunes de UI.
///
/// Se abre desde la navegación del operario y usa el mismo [LayoutPagina] y
/// [BarraNavegacionPrincipal] que el resto de esa sección.
class PruebaComponentesPage extends StatefulWidget {
  const PruebaComponentesPage({
    super.key,
    required this.superficie,
    required this.alCambiarSuperficie,
  });

  final SuperficiePagina superficie;
  final ValueChanged<SuperficiePagina> alCambiarSuperficie;

  @override
  State<PruebaComponentesPage> createState() => _PruebaComponentesPageState();
}

class _PruebaComponentesPageState extends State<PruebaComponentesPage> {
  EstadoContenidoTipo _tipoEstado = EstadoContenidoTipo.vacio;
  TipoAviso _tipoAviso = TipoAviso.informacion;
  String _estadoReclamo = 'en_proceso';
  int _activacionesFila = 0;
  int _reintentos = 0;

  void _notificar(
    TipoNotificacion tipo,
    String mensaje, {
    bool conAccion = false,
  }) {
    Notificaciones.mostrar(
      context,
      tipo: tipo,
      mensaje: mensaje,
      id: 'prueba-componentes',
      accion: conAccion
          ? AccionNotificacion(
              etiqueta: 'Probar acción',
              alActivar: () => Notificaciones.mostrar(
                context,
                tipo: TipoNotificacion.informacion,
                mensaje: 'Acción de notificación activada.',
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      Text('Catálogo interactivo', style: context.theme.typography.body.lg),
      const SizedBox(height: 4),
      Text(
        'Probá cada pieza y sus acciones. Estos ejemplos no modifican reclamos.',
        style: TextStyle(color: context.theme.colors.mutedForeground),
      ),
      const SizedBox(height: 20),
      _seccion('1 · LayoutPagina y BarraNavegacionPrincipal'),
      const Text(
        'Esta pantalla usa LayoutPagina. Cambiá la superficie y la barra '
        'inferior para probar su composición en Trabajo y Mapa.',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FButton(
            variant: widget.superficie == SuperficiePagina.contenido
                ? .primary
                : .outline,
            onPress: () =>
                widget.alCambiarSuperficie(SuperficiePagina.contenido),
            child: const Text('Margen de contenido'),
          ),
          FButton(
            variant: widget.superficie == SuperficiePagina.bordeABorde
                ? .primary
                : .outline,
            onPress: () =>
                widget.alCambiarSuperficie(SuperficiePagina.bordeABorde),
            child: const Text('Borde a borde'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _seccion('2 · EstadoReclamoBadge'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          EstadoReclamoBadge(estado: _estadoReclamo),
          for (final estado in ['pendiente', 'en_proceso', 'resuelto'])
            FButton(
              variant: .outline,
              onPress: () => setState(() => _estadoReclamo = estado),
              child: Text(_nombreVisible(estado)),
            ),
        ],
      ),
      const SizedBox(height: 20),
      _seccion('3 · FilaReclamo'),
      FilaReclamo(
        titulo: 'Luminaria apagada en la esquina',
        estado: _estadoReclamo,
        iconoCategoria: Icons.lightbulb_outline,
        metadatos: const ['Alumbrado público', 'Av. San Martín 1200'],
        alAbrir: () {
          setState(() => _activacionesFila++);
          _notificar(
            TipoNotificacion.informacion,
            'Abriste el reclamo de ejemplo ($_activacionesFila).',
          );
        },
      ),
      const SizedBox(height: 20),
      _seccion('4 · EstadoContenido'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tipo in EstadoContenidoTipo.values)
            FButton(
              variant: _tipoEstado == tipo ? .primary : .outline,
              onPress: () => setState(() => _tipoEstado = tipo),
              child: Text(_etiquetaEstado(tipo)),
            ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 230,
        child: EstadoContenido(
          tipo: _tipoEstado,
          titulo: switch (_tipoEstado) {
            EstadoContenidoTipo.vacio => 'Todavía no hay reclamos',
            EstadoContenidoTipo.sinResultados => 'No encontramos resultados',
            EstadoContenidoTipo.error => 'No pudimos cargar los reclamos',
          },
          descripcion: switch (_tipoEstado) {
            EstadoContenidoTipo.vacio =>
              'El estado vacío puede incluir una explicación breve.',
            EstadoContenidoTipo.sinResultados =>
              'Probá otra búsqueda o quitá los filtros.',
            EstadoContenidoTipo.error =>
              'El botón vuelve al estado vacío para simular un reintento.',
          },
          accion: _tipoEstado == EstadoContenidoTipo.error
              ? AccionContenido(
                  etiqueta: 'Reintentar ($_reintentos)',
                  alActivar: () => setState(() {
                    _reintentos++;
                    _tipoEstado = EstadoContenidoTipo.vacio;
                  }),
                )
              : null,
        ),
      ),
      const SizedBox(height: 20),
      _seccion('5 · AvisoEnLinea'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tipo in TipoAviso.values)
            FButton(
              variant: _tipoAviso == tipo ? .primary : .outline,
              onPress: () => setState(() => _tipoAviso = tipo),
              child: Text(_etiquetaAviso(tipo)),
            ),
        ],
      ),
      const SizedBox(height: 8),
      AvisoEnLinea(
        tipo: _tipoAviso,
        mensaje: 'Este mensaje queda junto al contenido al que se refiere.',
        accion: AccionAviso(
          etiqueta: 'Probar acción',
          alActivar: () => _notificar(
            TipoNotificacion.exito,
            'La acción del aviso respondió.',
          ),
        ),
      ),
      const SizedBox(height: 20),
      _seccion('6 · Dialogo y confirmarAccion'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FButton(onPress: _mostrarDialogo, child: const Text('Abrir diálogo')),
          FButton(
            variant: .outline,
            onPress: _confirmarAccion,
            child: const Text('Probar confirmación'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _seccion('7 · PanelInferior'),
      FButton(
        variant: .outline,
        onPress: _mostrarPanel,
        child: const Text('Abrir panel inferior'),
      ),
      const SizedBox(height: 20),
      _seccion('8 · Notificaciones'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tipo in TipoNotificacion.values)
            FButton(
              variant: .outline,
              onPress: () => _notificar(tipo, _mensajeNotificacion(tipo)),
              child: Text(_etiquetaNotificacion(tipo)),
            ),
          FButton(
            onPress: () => _notificar(
              TipoNotificacion.informacion,
              'Notificación con acción',
              conAccion: true,
            ),
            child: const Text('Con acción'),
          ),
        ],
      ),
    ],
  );

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      titulo,
      style: context.theme.typography.body.md.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Future<void> _mostrarDialogo() async {
    await Dialogo(
      titulo: 'Diálogo de ejemplo',
      contenido: const Text('Probá cerrar con cualquiera de las acciones.'),
      acciones: [
        AccionDialogo(
          etiqueta: 'Aceptar',
          tipo: TipoAccionDialogo.principal,
          alActivar: (context) => Navigator.of(context).pop(true),
        ),
        AccionDialogo(
          etiqueta: 'Cancelar',
          alActivar: (context) => Navigator.of(context).pop(false),
        ),
      ],
    ).mostrar<bool>(context);
  }

  Future<void> _confirmarAccion() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Confirmar ejemplo',
      descripcion: 'La confirmación devuelve verdadero al aceptar.',
      textoConfirmar: 'Confirmar',
    );
    if (confirmado && mounted) {
      _notificar(TipoNotificacion.exito, 'Confirmación aceptada.');
    }
  }

  Future<void> _mostrarPanel() async {
    await PanelInferior(
      titulo: 'Panel inferior de ejemplo',
      descripcion: 'Modal adaptable con cierre accesible.',
      contenido: const Text(
        'El contenido puede desplazarse si ocupa más espacio que la pantalla.',
      ),
      acciones: [
        FButton(
          onPress: () => Navigator.of(context).maybePop(),
          child: const Text('Listo'),
        ),
      ],
    ).mostrar<void>(context);
  }

  String _etiquetaEstado(EstadoContenidoTipo tipo) => switch (tipo) {
    EstadoContenidoTipo.vacio => 'Vacío',
    EstadoContenidoTipo.sinResultados => 'Sin resultados',
    EstadoContenidoTipo.error => 'Error',
  };

  String _etiquetaAviso(TipoAviso tipo) => switch (tipo) {
    TipoAviso.informacion => 'Info',
    TipoAviso.exito => 'Éxito',
    TipoAviso.advertencia => 'Atención',
    TipoAviso.error => 'Error',
  };

  String _etiquetaNotificacion(TipoNotificacion tipo) => switch (tipo) {
    TipoNotificacion.informacion => 'Info',
    TipoNotificacion.exito => 'Éxito',
    TipoNotificacion.advertencia => 'Atención',
    TipoNotificacion.error => 'Error',
  };

  String _mensajeNotificacion(TipoNotificacion tipo) => switch (tipo) {
    TipoNotificacion.informacion => 'Mensaje informativo de ejemplo.',
    TipoNotificacion.exito => 'La acción terminó correctamente.',
    TipoNotificacion.advertencia => 'Revisá este aviso antes de continuar.',
    TipoNotificacion.error => 'No se pudo completar la acción de ejemplo.',
  };

  String _nombreVisible(String estado) => switch (estado) {
    'pendiente' => 'Pendiente',
    'en_proceso' => 'En curso',
    _ => 'Resuelto',
  };
}
