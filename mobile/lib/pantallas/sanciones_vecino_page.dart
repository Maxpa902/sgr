import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../formato.dart';
import '../modelos/sancion.dart';
import '../modelos/usuario.dart';
import '../sesion/sesion.dart';
import '../widgets/componentes_ui.dart';

/// Sanciones de un vecino. El admin puede revocar las activas indicando un motivo.
class SancionesVecinoPage extends StatefulWidget {
  const SancionesVecinoPage({
    super.key,
    required this.sesion,
    required this.vecino,
  });

  final Sesion sesion;
  final Usuario vecino;

  @override
  State<SancionesVecinoPage> createState() => _SancionesVecinoPageState();
}

class _SancionesVecinoPageState extends State<SancionesVecinoPage> {
  late Future<SancionesDeVecino> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _pedirSanciones();
  }

  Future<SancionesDeVecino> _pedirSanciones() =>
      widget.sesion.api.listarSancionesDeVecino(widget.vecino.id);

  void _recargar() {
    setState(() {
      _futuro = _pedirSanciones();
    });
  }

  Future<void> _revocar(Sancion sancion) async {
    final revocada = await showFSheet<bool>(
      context: context,
      side: .btt,
      mainAxisMaxRatio: 0.9,
      useSafeArea: true,
      resizeToAvoidBottomInset: true,
      barrierDismissible: false,
      draggable: false,
      builder: (_) =>
          _RevocarSancionPanel(sesion: widget.sesion, sancion: sancion),
    );
    if (!mounted || revocada != true) return;
    Notificaciones.mostrar(
      context,
      tipo: TipoNotificacion.exito,
      mensaje: 'Sanción revocada.',
    );
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final vecino = widget.vecino;
    return Scaffold(
      appBar: AppBar(title: Text('${vecino.nombre} ${vecino.apellido}')),
      body: FutureBuilder<SancionesDeVecino>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: FCircularProgress());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return EstadoContenido(
              tipo: EstadoContenidoTipo.error,
              titulo: 'No se pudieron cargar las sanciones',
              descripcion: error is ApiException ? error.mensaje : null,
              accion: AccionContenido(
                etiqueta: 'Reintentar',
                alActivar: _recargar,
              ),
            );
          }

          final datos = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AvisoEnLinea(
                tipo: datos.estaSuspendido
                    ? TipoAviso.error
                    : TipoAviso.informacion,
                mensaje: datos.estaSuspendido
                    ? 'Suspendido hasta el ${fechaCorta(datos.suspendidoHasta!)}. '
                          'Mientras tanto no puede crear reclamos ni votar.'
                    : 'No está suspendido.',
              ),
              const SizedBox(height: 16),
              if (datos.sanciones.isEmpty)
                const EstadoContenido(
                  tipo: EstadoContenidoTipo.vacio,
                  titulo: 'Sin sanciones',
                )
              else
                for (final sancion in datos.sanciones) ...[
                  _TarjetaSancion(
                    sancion: sancion,
                    alRevocar: () => _revocar(sancion),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Una sanción: qué reclamo la causó, su estado y, si está activa, el botón para revocarla.
class _TarjetaSancion extends StatelessWidget {
  const _TarjetaSancion({required this.sancion, required this.alRevocar});

  final Sancion sancion;
  final VoidCallback alRevocar;

  @override
  Widget build(BuildContext context) {
    final colores = context.theme.colors;
    final textoChico = context.theme.typography.body.sm;

    final String estado;
    final Color colorEstado;
    if (sancion.revocada) {
      estado = 'Revocada el ${fechaCorta(sancion.revocadaEn!)}';
      colorEstado = colores.mutedForeground;
    } else if (sancion.activa) {
      estado = 'Suspende hasta el ${fechaCorta(sancion.terminaEn)}';
      colorEstado = colores.error;
    } else {
      estado = 'Terminó el ${fechaCorta(sancion.terminaEn)}';
      colorEstado = colores.mutedForeground;
    }

    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sancion.tituloReclamo,
              style: context.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rechazado por falso el ${fechaCorta(sancion.creadaEn)}',
              style: textoChico.copyWith(color: colores.mutedForeground),
            ),
            const SizedBox(height: 8),
            Text(
              estado,
              style: textoChico.copyWith(
                color: colorEstado,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (sancion.revocada) ...[
              const SizedBox(height: 4),
              Text(
                '${sancion.revocadaPor ?? 'Un administrador'}: '
                '${sancion.motivoRevocacion ?? 'sin motivo'}',
                style: textoChico,
              ),
            ],
            if (sancion.activa) ...[
              const SizedBox(height: 12),
              FButton(
                variant: .outline,
                onPress: alRevocar,
                child: const Text('Revocar sanción'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Panel para escribir el motivo y revocar. Devuelve `true` al cerrarse si se revocó.
class _RevocarSancionPanel extends StatefulWidget {
  const _RevocarSancionPanel({required this.sesion, required this.sancion});

  final Sesion sesion;
  final Sancion sancion;

  @override
  State<_RevocarSancionPanel> createState() => _RevocarSancionPanelState();
}

class _RevocarSancionPanelState extends State<_RevocarSancionPanel> {
  final _motivo = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _revocar() async {
    if (_guardando) return;
    final motivo = _motivo.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'Escribí el motivo de la revocación.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.sesion.api.revocarSancion(widget.sancion.id, motivo: motivo);
      if (!mounted) return;
      setState(() => _guardando = false);
      // Se cierra en el cuadro siguiente, cuando el panel ya permite volver atrás.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = error.mensaje;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo revocar la sanción.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PanelInferior(
    titulo: 'Revocar sanción',
    descripcion:
        'La sanción queda guardada como revocada. Si el vecino no tiene otra '
        'activa, deja de estar suspendido.',
    procesando: _guardando,
    contenido: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Reclamo: ${widget.sancion.tituloReclamo}'),
        const SizedBox(height: 12),
        FTextField.multiline(
          control: FTextFieldControl.managed(controller: _motivo),
          enabled: !_guardando,
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
          label: const Text('Motivo de la revocación'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: context.theme.colors.error)),
        ],
      ],
    ),
    acciones: [
      FButton(
        onPress: _guardando ? null : _revocar,
        child: Text(_guardando ? 'Revocando…' : 'Confirmar revocación'),
      ),
    ],
  );
}
