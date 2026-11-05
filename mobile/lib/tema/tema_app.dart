import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'colores.dart';

/// Tema y host de notificaciones limitados a una ruta de operario.
class TemaApp extends StatelessWidget {
  const TemaApp({super.key, required this.child});

  final Widget child;

  static final _temaForui = _crearTemaForui();

  static FThemeData _crearTemaForui() {
    final base = FThemeData(
      touch: true,
      colors: FColors.neutralLight.copyWith(
        background: ColoresApp.fondo,
        foreground: ColoresApp.textoPrincipal,
        primary: ColoresApp.principal,
        primaryForeground: ColoresApp.sobrePrincipal,
        // Forui también usa estos colores en botones outline y ghost.
        secondary: ColoresApp.secundarioSuave,
        secondaryForeground: ColoresApp.textoBotonSecundario,
        muted: ColoresApp.principalSuave,
        mutedForeground: ColoresApp.textoSecundario,
        destructive: ColoresApp.error,
        destructiveForeground: ColoresApp.sobrePrincipal,
        error: ColoresApp.error,
        errorForeground: ColoresApp.sobrePrincipal,
        card: ColoresApp.superficie,
        border: ColoresApp.borde,
      ),
    );

    return base.copyWith(
      buttonStyles: FVariantsDelta.delta([
        FVariantOperation.exact({
          FButtonVariant.primary,
        }, _colorAlPresionar(ColoresApp.principalPresionado)),
      ]),
    );
  }

  static FButtonSizesDelta _colorAlPresionar(Color color) =>
      FVariantsDelta.delta([
        FVariantOperation.all(
          FButtonStyleDelta.delta(
            decoration: FVariantsDelta.delta([
              FVariantOperation.exact({
                FTappableVariant.pressed,
              }, DecorationDelta.shapeDelta(color: color)),
            ]),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final material = Theme.of(context);
    final colores = material.colorScheme.copyWith(
      primary: ColoresApp.principal,
      onPrimary: ColoresApp.sobrePrincipal,
      secondary: ColoresApp.secundario,
      onSecondary: ColoresApp.sobreSecundario,
      surface: ColoresApp.superficie,
      onSurface: ColoresApp.textoPrincipal,
      error: ColoresApp.error,
      onError: ColoresApp.sobrePrincipal,
    );

    return Theme(
      data: material.copyWith(colorScheme: colores),
      child: FTheme(
        data: _temaForui,
        child: FToaster(child: child),
      ),
    );
  }
}
