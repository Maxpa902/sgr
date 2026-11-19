import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:forui/forui.dart';
import 'package:latlong2/latlong.dart';

import '../mapa/estilos.dart';
import '../mapa/zona.dart';
import '../modelos/reclamo_detalle_admin.dart';
import 'componentes_ui.dart';
import '../widgets/lista_votantes_sheet.dart';

class ContenidoDetalleReclamo extends StatelessWidget {
  const ContenidoDetalleReclamo({
    super.key,
    required this.reclamo,
    this.ocupado = false,
    this.alAsignar,
    this.alDesasignar,
    this.alRechazar,
    this.alVerVotantes,
    this.accionesOperario,
    this.responsableTexto,
    this.esAdmin = false,
    required this.mostrarMapaBase,
  });

  final ReclamoDetalleAdmin reclamo;
  final bool ocupado;
  final VoidCallback? alAsignar;
  final VoidCallback? alDesasignar;
  final VoidCallback? alRechazar;
  final VoidCallback? alVerVotantes;
  final Widget? accionesOperario;
  final String? responsableTexto;
  final bool esAdmin;
  final bool mostrarMapaBase;


  @override
  Widget build(BuildContext context) {
    final colorEstado = colorDelEstado(reclamo.estado);
    final colores = context.theme.colors;
    final fecha = reclamo.creadoEn.toLocal();
    final fechaTexto =
        '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year} · '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorEstado.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconoDeCategoria(reclamo.tipo.icono),
                color: colorEstado,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reclamo.tipo.nombre,
                style: TextStyle(
                  color: colores.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          reclamo.titulo,
          style: context.theme.typography.display.xl.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EstadoReclamoBadge(estado: reclamo.estado),
            Text(fechaTexto, style: TextStyle(color: colores.mutedForeground)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colores.muted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colores.border),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline, color: colores.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TituloSeccion(titulo: 'Responsable'),
                    const SizedBox(height: 4),
                    Text(
                      responsableTexto ??
                          reclamo.responsable?.nombreCompleto ??
                          'Sin responsable',
                      style: TextStyle(color: colores.mutedForeground),
                    ),
                    if (esAdmin &&
                        reclamo.responsable != null &&
                        (reclamo.asignadoEn != null ||
                            reclamo.asignadoPor != null)) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (reclamo.asignadoEn != null)
                            'Asignado ${_formatearFecha(reclamo.asignadoEn!)}',
                          if (reclamo.asignadoPor != null)
                            'por ${reclamo.asignadoPor!.nombreCompleto}',
                        ].join(' '),
                        style: context.theme.typography.body.sm.copyWith(
                          color: colores.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (esAdmin && reclamo.estado == 'pendiente')
                FButton(
                  variant: .outline,
                  size: .sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: ocupado ? null : alAsignar,
                  child: Text(
                    reclamo.responsable == null ? 'Asignar' : 'Cambiar',
                  ),
                ),
            ],
          ),
        ),
        if (esAdmin && reclamo.ultimaDesasignacion != null) ...[
          const SizedBox(height: 10),
          Text(
            'Último responsable desasignado: ${reclamo.ultimaDesasignacion!.responsable.nombreCompleto}',
            style: context.theme.typography.body.sm.copyWith(
              color: colores.mutedForeground,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${_formatearFecha(reclamo.ultimaDesasignacion!.creadoEn)} · por ${reclamo.ultimaDesasignacion!.autor?.nombreCompleto ?? 'Sistema'}',
            style: context.theme.typography.body.sm.copyWith(
              color: colores.mutedForeground,
            ),
          ),
        ],
        if (esAdmin &&
            reclamo.estado == 'pendiente' &&
            reclamo.responsable != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FButton(
              variant: .ghost,
              size: .sm,
              mainAxisSize: MainAxisSize.min,
              onPress: ocupado ? null : alDesasignar,
              child: const Text('Desasignar'),
            ),
          ),
        ],
        if (esAdmin &&
            (reclamo.estado == 'pendiente' ||
                reclamo.estado == 'en_proceso')) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FButton(
              variant: .destructive,
              size: .sm,
              mainAxisSize: MainAxisSize.min,
              onPress: ocupado ? null : alRechazar,
              prefix: const Icon(Icons.block),
              child: const Text('Rechazar reclamo'),
            ),
          ),
        ],
        if (accionesOperario != null) ...[
          const SizedBox(height: 16),
          accionesOperario!,
        ],
        if (reclamo.cierre case final cierre?) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TituloSeccion(
                  titulo: reclamo.estado == 'rechazado'
                      ? 'Motivo del rechazo'
                      : 'Detalle de resolución',
                ),
                if (cierre.observacion?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(cierre.observacion!.trim()),
                ],
                const SizedBox(height: 8),
                Text(
                  '${cierre.autor?.nombreCompleto ?? 'Sistema'} · ${_formatearFecha(cierre.creadoEn)}',
                  style: TextStyle(color: colores.mutedForeground),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _TituloSeccion(titulo: 'Ubicación'),
        if (_tieneTexto(reclamo.direccion)) ...[
          const SizedBox(height: 6),
          Text(reclamo.direccion!.trim()),
        ],
        const SizedBox(height: 12),
        if (reclamo.latitud.isFinite &&
            reclamo.longitud.isFinite &&
            reclamo.latitud.abs() <= 90 &&
            reclamo.longitud.abs() <= 180)
          _MapaRecortado(reclamo: reclamo, mostrarMapaBase: mostrarMapaBase)
        else
          const Text('Ubicación no disponible'),
        const SizedBox(height: 8),
        Text(
          '${reclamo.latitud.toStringAsFixed(5)}, '
          '${reclamo.longitud.toStringAsFixed(5)}',
          style: context.theme.typography.body.sm.copyWith(
            color: colores.mutedForeground,
          ),
        ),
        if (_tieneTexto(reclamo.descripcion)) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const _TituloSeccion(titulo: 'Descripción'),
          const SizedBox(height: 8),
          Text(reclamo.descripcion!.trim()),
        ],
        if (reclamo.fotos.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _TituloSeccion(titulo: 'Fotos'),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: reclamo.fotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  reclamo.fotos[index],
                  width: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 250,
                    color: colores.muted,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 32),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const _TituloSeccion(titulo: 'Seguimiento'),
        const SizedBox(height: 12),
        for (final entrada in _entradasSeguimiento.take(3))
          _FilaSeguimiento(entrada: entrada),
        if (reclamo.historial == null)
          Text(
            'El historial de cambios no está disponible.',
            style: TextStyle(color: colores.mutedForeground),
          )
        else if (reclamo.historial!.isEmpty)
          Text(
            'No hay cambios de estado registrados.',
            style: TextStyle(color: colores.mutedForeground),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: FButton(
            variant: .ghost,
            size: .sm,
            mainAxisSize: MainAxisSize.min,
            onPress: () => _mostrarHistorial(context),
            prefix: const Icon(Icons.history),
            child: const Flexible(child: Text('Ver historial completo')),
          ),
        ),
        if (esAdmin) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const _TituloSeccion(titulo: 'Reportado por'),
          const SizedBox(height: 8),
          if (reclamo.creador.isNotEmpty) Text(reclamo.creador),
          if (reclamo.emailCreador.isNotEmpty) ...[
            if (reclamo.creador.isNotEmpty) const SizedBox(height: 3),
            Text(
              reclamo.emailCreador,
              style: TextStyle(color: colores.mutedForeground),
            ),
          ],

          if (reclamo.sancionesActivasCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vecino suspendido por un reclamo falso.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          FButton(
            variant: .outline,
            onPress: alVerVotantes,
            prefix: const Icon(Icons.people_alt_outlined),
            child: const Text('Ver lista de votantes'),
          ),
        ],
      ],
    );
  }

  bool _tieneTexto(String? texto) => texto != null && texto.trim().isNotEmpty;

  List<_EntradaSeguimiento> get _entradasSeguimiento {
    final historial = reclamo.historial ?? const <EventoEstadoReclamo>[];
    final entradas = <_EntradaSeguimiento>[
      if (!historial.any((evento) => evento.estado == 'pendiente'))
        _EntradaSeguimiento(
          titulo: 'Reclamo recibido',
          fecha: reclamo.creadoEn,
          autor: esAdmin && reclamo.creador.isNotEmpty ? reclamo.creador : null,
        ),
      for (final evento in historial)
        _EntradaSeguimiento(
          titulo: evento.estado == 'pendiente'
              ? 'Reclamo recibido'
              : nombreDelEstado(evento.estado),
          fecha: evento.creadoEn,
          autor: esAdmin || evento.autor?.id == reclamo.responsable?.id
              ? evento.autor?.nombreCompleto
              : null,
          observacion: evento.observacion,
          interna: evento.visibilidad == 'interna',
        ),
    ];
    return entradas.reversed.toList(growable: false);
  }

  String _formatearFecha(DateTime fecha) {
    final local = fecha.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _mostrarHistorial(BuildContext context) {
    _mostrarPanel(
      context,
      titulo: 'Historial del reclamo',
      contenido: [
        if (reclamo.historial == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('El historial de cambios no está disponible.'),
          )
        else if (reclamo.historial!.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('No hay cambios de estado registrados.'),
          ),
        for (final entrada in _entradasSeguimiento)
          _FilaSeguimiento(entrada: entrada),
      ],
    );
  }

  void _mostrarPanel(
    BuildContext context, {
    required String titulo,
    required List<Widget> contenido,
  }) {
    showFSheet<void>(
      context: context,
      side: .btt,
      mainAxisMaxRatio: 0.9,
      builder: (context) => _SuperficiePanel(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: context.theme.typography.body.lg),
                const SizedBox(height: 16),
                ...contenido,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntradaSeguimiento {
  const _EntradaSeguimiento({
    required this.titulo,
    required this.fecha,
    this.autor,
    this.observacion,
    this.interna = false,
  });

  final String titulo;
  final DateTime fecha;
  final String? autor;
  final String? observacion;
  final bool interna;
}

class _FilaSeguimiento extends StatelessWidget {
  const _FilaSeguimiento({required this.entrada});

  final _EntradaSeguimiento entrada;

  @override
  Widget build(BuildContext context) {
    final fecha = entrada.fecha.toLocal();
    final fechaTexto =
        '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year} · '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
    final muted = context.theme.colors.mutedForeground;
    final observacion = entrada.observacion?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.radio_button_checked,
            size: 18,
            color: context.theme.colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entrada.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    fechaTexto,
                    if (entrada.autor?.isNotEmpty == true) entrada.autor!,
                  ].join(' · '),
                  style: TextStyle(color: muted),
                ),
                if (observacion != null && observacion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  if (entrada.interna)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: FBadge(
                        variant: .secondary,
                        child: const Text('Interna'),
                      ),
                    ),
                  Text(observacion),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) => Text(
    titulo,
    style: context.theme.typography.body.sm.copyWith(
      fontWeight: FontWeight.w700,
    ),
  );
}

class _MapaRecortado extends StatefulWidget {
  const _MapaRecortado({required this.reclamo, required this.mostrarMapaBase});

  final ReclamoDetalleAdmin reclamo;
  final bool mostrarMapaBase;

  @override
  State<_MapaRecortado> createState() => _MapaRecortadoState();
}

class _MapaRecortadoState extends State<_MapaRecortado> {
  bool _errorMapa = false;

  @override
  Widget build(BuildContext context) {
    final reclamo = widget.reclamo;
    final punto = LatLng(reclamo.latitud, reclamo.longitud);
    final color = colorDelEstado(reclamo.estado);
    final icono = iconoDeCategoria(reclamo.tipo.icono);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 240,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: punto,
                initialZoom: ZonaDelMapa.zoomCercano,
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
                    },
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: punto,
                      width: 52,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(icono, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
                const Align(
                  alignment: Alignment.bottomLeft,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(3),
                      child: Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                        softWrap: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_errorMapa)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No se pudieron cargar algunas partes del mapa.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
