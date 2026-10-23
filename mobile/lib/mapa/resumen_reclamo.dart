import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../formato.dart';
import '../modelos/reclamo_mapa.dart';
import '../sesion/sesion.dart';
import 'estilos.dart';

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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.sesion.obtenerVotantes(widget.reclamo.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final votantes = snapshot.data ?? [];
            if (votantes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Aún no hay votos registrados para este reclamo.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Vecinos que votaron',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: votantes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final voto = votantes[index];
                        final esConfirma = voto['valor'] == 'confirma';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: esConfirma
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            child: Icon(
                              esConfirma
                                  ? Icons.thumb_up
                                  : Icons.thumb_down,
                              color: esConfirma
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              size: 18,
                            ),
                          ),
                          title: Text(voto['usuario'] as String? ?? 'Usuario'),
                          subtitle: Text(
                            esConfirma
                                ? 'Confirmó el reclamo'
                                : 'Desmintió el reclamo',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

    final esMiReclamoCreado = widget.sesion.usuario?.id != null &&
        widget.reclamo.usuarioId == widget.sesion.usuario?.id;

    final estaConfirmado = _miVotoActual == 'confirma';
    final estaDesmentido = _miVotoActual == 'desmiente';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // AVISO EN LA PARTE SUPERIOR
            if (_mensajeNotificacion != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  _mensajeNotificacion!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
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
                          color: Colors.grey.shade300,
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
                Chip(
                  label: Text(nombreDelEstado(reclamo.estado)),
                  labelStyle: const TextStyle(color: Colors.white),
                  backgroundColor: colorEstado,
                  side: BorderSide.none,
                ),
                Text(
                  'Cargado ${haceCuanto(reclamo.creadoEn)}',
                  style: textos.bodyMedium,
                ),
              ],
            ),
            if (reclamo.destacado) ...[
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
                          ? Colors.green.shade600
                          : Colors.transparent,
                      foregroundColor:
                          estaConfirmado ? Colors.white : Colors.green.shade700,
                      side: BorderSide(
                        color: esMiReclamoCreado
                            ? Colors.grey.shade400
                            : Colors.green.shade600,
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
                          ? Colors.red.shade600
                          : Colors.transparent,
                      foregroundColor:
                          estaDesmentido ? Colors.white : Colors.red.shade700,
                      side: BorderSide(
                        color: esMiReclamoCreado
                            ? Colors.grey.shade400
                            : Colors.red.shade600,
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
          ],
        ),
      ),
    );
  }
}