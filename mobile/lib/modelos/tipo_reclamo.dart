/// Una categoría de reclamo, por ejemplo "Agua potable".
class TipoReclamo {
  const TipoReclamo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.icono,
    this.activo = true,
  });

  factory TipoReclamo.fromJson(Map<String, dynamic> json) {
    final rawActivo = json['activo'];
    final bool activoParseado = switch (rawActivo) {
      bool v => v,
      int v => v == 1,
      num v => v.toInt() == 1,
      String v => v.trim().toLowerCase() == 'true' || v.trim() == '1',
      _ => true,
    };

    return TipoReclamo(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      icono: json['icono'] as String?,
      activo: activoParseado,
    );
  }

  final int id;
  final String nombre;
  final String? descripcion;

  /// Clave del ícono: `electricidad`, `alumbrado`, `agua`, `cloacas` o
  /// `telefonia`. Puede faltar en categorías nuevas.
  final String? icono;

  final bool activo;
}
