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
  String? _mensajeNotificacion;

  @override
  void initState() {
    super.initState();
    _confirmaciones = widget.reclamo.confirmaciones;
    _desmentidas = widget.reclamo.desmentidas;
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    setState(() {
      _mensajeNotificacion = mensaje;
    });
  }

  Future<void> _votar(String valor) async {
    if (_votando) return;
    setState(() => _votando = true);

    try {
      final res = await widget.sesion.votarReclamo(widget.reclamo.id, valor);
      if (mounted) {
        setState(() {
          _confirmaciones = res['confirmaciones'] as int;
          _desmentidas = res['desmentidas'] as int;
        });
        _mostrarMensaje(
          res['message']?.toString() ?? 'Voto registrado correctamente',
        );
        widget.alVotar?.call();
      }
    } on ApiException catch (e) {
      _mostrarMensaje(e.mensaje, esError: true);
    } catch (e) {
      _mostrarMensaje('No se pudo registrar tu voto.', esError: true);
    } finally {
      if (mounted) setState(() => _votando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reclamo = widget.reclamo;
    final textos = Theme.of(context).textTheme;
    final colorEstado = colorDelEstado(reclamo.estado);
    final lugar = reclamo.direccion == null
        ? reclamo.tipo.nombre
        : '${reclamo.tipo.nombre} · ${reclamo.direccion}';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    onPressed: _votando ? null : () => _votar('confirma'),
                    icon: const Icon(Icons.thumb_up_outlined),
                    label: Text('Confirmar ($_confirmaciones)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _votando ? null : () => _votar('desmiente'),
                    icon: const Icon(Icons.thumb_down_outlined),
                    label: Text('Desmentir ($_desmentidas)'),
                  ),
                ),
              ],
            ),
            if (_mensajeNotificacion != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _mensajeNotificacion!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}