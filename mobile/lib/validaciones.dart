/// Validaciones de los formularios. Repiten las reglas del server para avisar
/// los errores antes de enviar; el server igual los vuelve a comprobar.
library;

final _formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _formatoDni = RegExp(r'^\d{7,8}$');

/// Devuelve un validador que exige completar el campo.
String? Function(String?) obligatorio(String mensaje) {
  return (valor) => (valor == null || valor.trim().isEmpty) ? mensaje : null;
}

String? validarEmail(String? valor) {
  final email = valor?.trim() ?? '';
  if (email.isEmpty) {
    return 'Ingresá tu email.';
  }
  if (!_formatoEmail.hasMatch(email)) {
    return 'Revisá el email: parece incompleto.';
  }
  return null;
}

/// Quita puntos, espacios y guiones: `30.111.222` queda `30111222`.
String limpiarDni(String dni) => dni.replaceAll(RegExp(r'[\s.\-]'), '');

String? validarDni(String? valor) {
  final dni = limpiarDni(valor ?? '');
  if (dni.isEmpty) {
    return 'Ingresá tu DNI.';
  }
  if (!_formatoDni.hasMatch(dni)) {
    return 'El DNI debe tener 7 u 8 números.';
  }
  return null;
}

String? validarPasswordNueva(String? valor) {
  if (valor == null || valor.isEmpty) {
    return 'Elegí una contraseña.';
  }
  if (valor.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres.';
  }
  return null;
}
