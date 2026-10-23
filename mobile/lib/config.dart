import 'package:flutter/foundation.dart';

/// Dirección del servidor Laravel.
///
/// Puede cambiarse con `--dart-define=SERVER_URL=...`. Sin configuración
/// adicional funciona en Android Emulator, Chrome y las plataformas de
/// escritorio ejecutadas en esta computadora.
String get serverUrl {
  const configuredUrl = String.fromEnvironment('SERVER_URL');

  if (configuredUrl.isNotEmpty) {
    return configuredUrl;
  }

  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8081'
      : 'http://localhost:8081';
}
