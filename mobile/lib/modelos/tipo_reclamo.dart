/// Una categoría de reclamo, por ejemplo "Agua potable".
class TipoReclamo {
  const TipoReclamo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.icono,
  });

  factory TipoReclamo.fromJson(Map<String, dynamic> json) {
    return TipoReclamo(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      icono: json['icono'] as String?,
    );
  }

  final int id;
  final String nombre;
  final String? descripcion;

  /// Clave del ícono: `electricidad`, `alumbrado`, `agua`, `cloacas` o
  /// `telefonia`. Puede faltar en categorías nuevas.
  final String? icono;
}
