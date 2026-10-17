import 'package:flutter/material.dart';

import '../formato.dart';
import '../modelos/reclamo_mapa.dart';
import 'estilos.dart';

/// Panel que aparece abajo al tocar un pin, con lo principal del reclamo.
class ResumenReclamo extends StatelessWidget {
  const ResumenReclamo({super.key, required this.reclamo});

  final ReclamoMapa reclamo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colorEstado = colorDelEstado(reclamo.estado);
    final lugar = reclamo.direccion == null
        ? reclamo.tipo.nombre
        : '${reclamo.tipo.nombre} · ${reclamo.direccion}';

    // Se puede desplazar por si no entra en pantallas chicas o con letra grande.
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
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.thumb_up_alt_outlined, size: 20),
                const SizedBox(width: 6),
                Text(
                  '${reclamo.confirmaciones} '
                  '${reclamo.confirmaciones == 1 ? 'confirma' : 'confirman'}',
                ),
                const SizedBox(width: 20),
                const Icon(Icons.thumb_down_alt_outlined, size: 20),
                const SizedBox(width: 6),
                Text(
                  '${reclamo.desmentidas} '
                  '${reclamo.desmentidas == 1 ? 'lo desmiente' : 'lo desmienten'}',
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
            Text(
              'Pronto vas a poder ver las fotos, votar y comentar desde acá.',
              style: textos.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
