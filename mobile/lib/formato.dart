/// Cuánto tiempo pasó desde [fecha], en palabras: "hace 3 horas".
String haceCuanto(DateTime fecha, {DateTime? ahora}) {
  final diferencia = (ahora ?? DateTime.now()).difference(fecha);

  if (diferencia.inMinutes < 1) {
    return 'recién';
  }
  if (diferencia.inHours < 1) {
    return _hace(diferencia.inMinutes, 'minuto', 'minutos');
  }
  if (diferencia.inDays < 1) {
    return _hace(diferencia.inHours, 'hora', 'horas');
  }
  if (diferencia.inDays < 30) {
    return _hace(diferencia.inDays, 'día', 'días');
  }

  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return 'el $dia/$mes/${fecha.year}';
}

String _hace(int cantidad, String singular, String plural) {
  return 'hace $cantidad ${cantidad == 1 ? singular : plural}';
}
