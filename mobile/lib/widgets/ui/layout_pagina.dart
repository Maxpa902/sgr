import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Superficie que ocupa el cuerpo de una [LayoutPagina].
enum SuperficiePagina { contenido, bordeABorde }

/// Estructura común para una página de la app.
///
/// Recibe el contenido ya construido. La pantalla que la usa conserva su
/// navegación, estado y lógica de negocio.
class LayoutPagina extends StatelessWidget {
  const LayoutPagina({
    super.key,
    required this.titulo,
    required this.contenido,
    this.accionesEncabezado = const [],
    this.alVolver,
    this.pie,
    this.superficie = SuperficiePagina.contenido,
    this.redimensionarConTeclado = true,
  });

  final String titulo;
  final Widget contenido;
  final List<Widget> accionesEncabezado;
  final VoidCallback? alVolver;
  final Widget? pie;
  final SuperficiePagina superficie;
  final bool redimensionarConTeclado;

  @override
  Widget build(BuildContext context) {
    final Widget header = alVolver == null
        ? FHeader(title: Text(titulo), suffixes: accionesEncabezado)
        : FHeader.nested(
            title: Text(titulo),
            prefixes: [FHeaderAction.back(onPress: alVolver)],
            suffixes: accionesEncabezado,
          );

    return FScaffold(
      childPad: false,
      resizeToAvoidBottomInset: redimensionarConTeclado,
      header: ColoredBox(color: context.theme.colors.card, child: header),
      footer: pie,
      child: superficie == SuperficiePagina.contenido
          ? Padding(padding: const EdgeInsets.all(16), child: contenido)
          : contenido,
    );
  }
}
