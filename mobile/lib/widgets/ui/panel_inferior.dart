import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Presenta el contenido en un modal inferior de Forui.
///
/// No incorpora sheets persistentes. Si el panel debe permitir tocar el mapa,
/// ese es otro flujo y requiere una decisión de interacción de la pantalla.
class PanelInferior extends StatelessWidget {
  const PanelInferior({
    super.key,
    required this.titulo,
    required this.contenido,
    this.descripcion,
    this.acciones = const [],
    this.procesando = false,
    this.semanticsLabel,
    this.proporcionAlturaMaxima,
    this.maxLineasTitulo,
  });

  final String titulo;
  final Widget contenido;
  final String? descripcion;
  final List<Widget> acciones;
  final bool procesando;
  final String? semanticsLabel;
  final double? proporcionAlturaMaxima;
  final int? maxLineasTitulo;

  /// Abre el panel modal inferior; el host `FScaffold` no tiene que cambiar.
  Future<T?> mostrar<T>(BuildContext context) => showFSheet<T>(
    context: context,
    side: .btt,
    mainAxisMaxRatio: proporcionAlturaMaxima ?? 0.9,
    useSafeArea: true,
    resizeToAvoidBottomInset: true,
    barrierDismissible: !procesando,
    draggable: !procesando,
    builder: (sheetContext) => _buildContenido(sheetContext),
  );

  Widget _buildContenido(BuildContext context) {
    final borderRadius = const BorderRadius.vertical(top: Radius.circular(20));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.theme.colors.card,
        border: Border(top: BorderSide(color: context.theme.colors.border)),
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: PopScope(
          canPop: !procesando,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height *
                    (proporcionAlturaMaxima ?? 0.85),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            label: semanticsLabel ?? titulo,
                            child: Text(
                              titulo,
                              maxLines: maxLineasTitulo,
                              overflow: maxLineasTitulo == null
                                  ? null
                                  : TextOverflow.ellipsis,
                              style: context.theme.typography.body.lg.copyWith(
                                color: context.theme.colors.foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (!procesando)
                          FButton.icon(
                            variant: .ghost,
                            semanticsLabel: 'Cerrar panel',
                            semanticsTooltip: 'Cerrar panel',
                            onPress: () => Navigator.of(context).pop(),
                            child: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    if (descripcion case final value?) ...[
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: context.theme.typography.body.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Flexible(child: SingleChildScrollView(child: contenido)),
                    if (acciones.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      for (var index = 0; index < acciones.length; index++) ...[
                        if (index > 0) const SizedBox(height: 8),
                        IgnorePointer(
                          ignoring: procesando,
                          child: acciones[index],
                        ),
                      ],
                    ],
                    if (procesando) ...[
                      const SizedBox(height: 8),
                      const Text('Procesando…'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildContenido(context);
}
