/// Dirección del server Laravel.
///
/// Se puede cambiar al correr la app con `--dart-define=SERVER_URL=...`.
/// El valor por defecto sirve para el emulador de Android, donde `10.0.2.2`
/// es la computadora en la que corre Docker.
const serverUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'http://10.0.2.2:8081',
);
