import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Agrega actualización al deslizar a un contenido desplazable.
///
/// El [child] debe ser desplazable y usar [AlwaysScrollableScrollPhysics]
/// para que el gesto también funcione cuando su contenido no llena la pantalla.
class DeslizarParaActualizar extends StatelessWidget {
  const DeslizarParaActualizar({
    super.key,
    required this.alActualizar,
    required this.child,
  });

  final Future<void> Function() alActualizar;
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: alActualizar,
    color: context.theme.colors.primary,
    backgroundColor: context.theme.colors.background,
    child: child,
  );
}
