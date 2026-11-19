import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../formato.dart';
import '../modelos/reclamo_mapa.dart';
import '../sesion/sesion.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/componentes_ui.dart';
import 'estilos.dart';
import '../widgets/comentarios_reclamo.dart';
import '../widgets/lista_votantes_sheet.dart';
import '../widgets/seguimiento_reclamo.dart';

/// Panel que aparece abajo al tocar un pin, con lo principal del reclamo.
class ResumenReclamo extends StatefulWidget {
  const ResumenReclamo({
    super.key,
    required this.reclamo,
    required this.sesion,
    this.alVotar,
  });

  final ReclamoMapa reclamo;
  final Sesion sesion;
  final VoidCallback? alVotar;

  @override
  State<ResumenReclamo> createState() => _ResumenReclamoState();
}

class _ResumenReclamoState extends State<ResumenReclamo> {
  late int _confirmaciones;
  late int _desmentidas;
  bool _votando = false;
  String? _miVotoActual;
  String? _mensajeNotificacion;

  @override
  void initState() {
    super.initState();
    _confirmaciones = widget.reclamo.confirmaciones;
    _desmentidas = widget.reclamo.desmentidas;
    // Carga el voto previo traído desde el servidor
    _miVotoActual = widget.reclamo.miVoto;
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    setState(() {
      _mensajeNotificacion = mensaje;
    });
  }

  Future<void> _votar(String valor) async {
    if (_votando) return;
    setState(() {
      _votando = true;
      _mensajeNotificacion = null;
    });

    try {
      final res = await widget.sesion.votarReclamo(widget.reclamo.id, valor);
      if (mounted) {
        final bool votoRetirado = _miVotoActual == valor;

        setState(() {
          _confirmaciones = res['confirmaciones'] as int;
          _desmentidas = res['desmentidas'] as int;

          if (votoRetirado) {
            _miVotoActual = null;
          } else {
            _miVotoActual = valor;
          }
        });

        final textoMensaje = votoRetirado
            ? 'Se quitó tu voto correctamente'
            : (res['message']?.toString() ?? 'Voto registrado correctamente');

        _mostrarMensaje(textoMensaje);
        widget.alVotar?.call();
      }
    } on ApiException catch (e) {
      _mostrarMensaje(e.mensaje);
    } catch (e) {
      _mostrarMensaje('No se pudo registrar tu voto.');
    } finally {
      if (mounted) setState(() => _votando = false);
    }
  }

  void _mostrarListaVotantes(BuildContext context) {
    ListaVotantesSheet.mostrar(
      context,
      sesion: widget.sesion,
      reclamoId: widget.reclamo.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reclamo = widget.reclamo;
    final textos = Theme.of(context).textTheme;
    final colorEstado = colorDelEstado(reclamo.estado);
    final lugar = reclamo.direccion == null
        ? reclamo.tipo.nombre
        : '${reclamo.tipo.nombre} · ${reclamo.direccion}';

    final esMiReclamoCreado =
        widget.sesion.usuario?.id != null &&
        widget.reclamo.usuarioId == widget.sesion.usuario?.id;

    final estaConfirmado = _miVotoActual == 'confirma';
    final estaDesmentido = _miVotoActual == 'desmiente';

    final puntajeNetoActual = _confirmaciones - _desmentidas;
    final esDestacadoActual = puntajeNetoActual >= ReclamoMapa.destacadoDesde;

    return TemaApp(
      conNotificaciones: false,
      child: SafeArea(
        child: SingleChildScrollView(
          // Abajo deja lugar para el teclado, así no tapa el campo de comentario.
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barrita superior de arrastre del modal
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ColoresApp.borde,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (_mensajeNotificacion != null) ...[
                AvisoEnLinea(
                  tipo: TipoAviso.informacion,
                  mensaje: _mensajeNotificacion!,
                ),
                const SizedBox(height: 14),
              ],

              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorEstado,
                    foregroundColor: Colors.white,
                    child: Icon(iconoDeCategoria(reclamo.tipo.icono)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reclamo.titulo, style: textos.titleLarge),
                        Text(lugar, style: textos.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              if (reclamo.descripcion != null &&
                  reclamo.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(reclamo.descripcion!, style: textos.bodyMedium),
              ],
              if (reclamo.fotos.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: reclamo.fotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          reclamo.fotos[index],
                          fit: BoxFit.cover,
                          width: 240,
                          errorBuilder: (_, __, ___) => Container(
                            width: 140,
                            color: ColoresApp.borde,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  EstadoReclamoBadge(estado: reclamo.estado),
                  Text(
                    'Cargado ${haceCuanto(reclamo.creadoEn)}',
                    style: textos.bodyMedium,
                  ),
                ],
              ),
              if (esDestacadoActual) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('Muchos vecinos confirmaron este reclamo.'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (esMiReclamoCreado || _votando)
                          ? null
                          : () => _votar('confirma'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: estaConfirmado
                            ? ColoresApp.exito
                            : Colors.transparent,
                        foregroundColor: estaConfirmado
                            ? Colors.white
                            : ColoresApp.exito,
                        side: BorderSide(
                          color: esMiReclamoCreado
                              ? ColoresApp.borde
                              : ColoresApp.exito,
                          width: 1.5,
                        ),
                      ),
                      icon: Icon(
                        estaConfirmado
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                      ),
                      label: Text('Confirmar ($_confirmaciones)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (esMiReclamoCreado || _votando)
                          ? null
                          : () => _votar('desmiente'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: estaDesmentido
                            ? ColoresApp.error
                            : Colors.transparent,
                        foregroundColor: estaDesmentido
                            ? Colors.white
                            : ColoresApp.error,
                        side: BorderSide(
                          color: esMiReclamoCreado
                              ? ColoresApp.borde
                              : ColoresApp.error,
                          width: 1.5,
                        ),
                      ),
                      icon: Icon(
                        estaDesmentido
                            ? Icons.thumb_down
                            : Icons.thumb_down_outlined,
                      ),
                      label: Text('Desmentir ($_desmentidas)'),
                    ),
                  ),
                ],
              ),
              if (_confirmaciones > 0 || _desmentidas > 0) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _mostrarListaVotantes(context),
                    icon: const Icon(Icons.people_alt_outlined, size: 18),
                    label: const Text('Ver lista de votantes'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              SeguimientoReclamo(sesion: widget.sesion, reclamoId: reclamo.id),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              ComentariosReclamo(sesion: widget.sesion, reclamoId: reclamo.id),
            ],
          ),
        ),
      ),
    );
  }
}
