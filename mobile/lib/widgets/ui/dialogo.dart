import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Jerarquía de una acción dentro de [Dialogo].
enum TipoAccionDialogo { principal, secundaria, destructiva }

/// Acción de diálogo. El callback recibe el contexto de la ruta del diálogo.
class AccionDialogo {
  const AccionDialogo({
    required this.etiqueta,
    required this.alActivar,
    this.tipo = TipoAccionDialogo.secundaria,
  });

  final String etiqueta;
  final ValueChanged<BuildContext> alActivar;
  final TipoAccionDialogo tipo;

  FButtonVariant get _variante => switch (tipo) {
    TipoAccionDialogo.principal => .primary,
    TipoAccionDialogo.secundaria => .outline,
    TipoAccionDialogo.destructiva => .destructive,
  };
}

/// Composición reutilizable para un diálogo centrado.
///
/// Invocá [mostrar] desde una pantalla para presentarlo. Cada acción decide
/// explícitamente si cierra el diálogo con `Navigator.pop`. Las acciones se
/// apilan en el orden recibido: en confirmaciones, la acción va antes que
/// cancelar.
class Dialogo extends StatelessWidget {
  const Dialogo({
    super.key,
    required this.titulo,
    required this.contenido,
    required this.acciones,
    this.procesando = false,
    this.mensajeError,
    this.semanticsLabel,
  }) : assert(acciones.length > 0);

  final String titulo;
  final Widget contenido;
  final List<AccionDialogo> acciones;
  final bool procesando;
  final String? mensajeError;
  final String? semanticsLabel;

  /// Presenta este diálogo sobre la ruta actual con el tema del llamador.
  Future<T?> mostrar<T>(
    BuildContext context, {
    bool barreraDescartable = true,
  }) => showFDialog<T>(
    context: context,
    barrierDismissible: barreraDescartable && !procesando,
    useSafeArea: true,
    builder: (dialogContext, _, animation) => FDialog(
      animation: animation,
      semanticsLabel: semanticsLabel ?? titulo,
      builder: (dialogContext, _) =>
          PopScope(canPop: !procesando, child: _buildContenido(dialogContext)),
    ),
  );

  Widget _buildContenido(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: DefaultTextStyle.merge(
        style: context.theme.typography.body.md.copyWith(
          color: context.theme.colors.foreground,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: context.theme.typography.body.lg.copyWith(
                color: context.theme.colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            contenido,
            if (mensajeError case final error?) ...[
              const SizedBox(height: 16),
              FAlert(
                variant: .destructive,
                title: const Text('No se pudo completar'),
                subtitle: Text(error),
              ),
            ],
            const SizedBox(height: 20),
            for (var index = 0; index < acciones.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              FButton(
                variant: acciones[index]._variante,
                onPress: procesando
                    ? null
                    : () => acciones[index].alActivar(context),
                child: Text(
                  procesando &&
                          acciones[index].tipo == TipoAccionDialogo.principal
                      ? 'Procesando…'
                      : acciones[index].etiqueta,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => _buildContenido(context);
}

/// Estilo semántico de la acción confirmada.
enum TipoConfirmacionAccion { normal, destructiva }

/// Pide confirmación y devuelve `false` también al cerrar o cancelar.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String descripcion,
  required String textoConfirmar,
  TipoConfirmacionAccion variante = TipoConfirmacionAccion.normal,
  String textoCancelar = 'Cancelar',
}) async {
  final destructive = variante == TipoConfirmacionAccion.destructiva;
  final resultado = await Dialogo(
    titulo: titulo,
    contenido: Text(descripcion),
    acciones: [
      AccionDialogo(
        etiqueta: textoConfirmar,
        tipo: destructive
            ? TipoAccionDialogo.destructiva
            : TipoAccionDialogo.principal,
        alActivar: (dialogContext) => Navigator.of(dialogContext).pop(true),
      ),
      AccionDialogo(
        etiqueta: textoCancelar,
        alActivar: (dialogContext) => Navigator.of(dialogContext).pop(false),
      ),
    ],
  ).mostrar<bool>(context);

  return resultado ?? false;
}
