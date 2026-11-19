/// Una cuenta del sistema, tal como la devuelve el server.
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.rol,
    this.telefono,
    this.activo,
    this.suspendidoHasta,
    required this.sancionesActivas,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      email: json['email'] as String,
      rol: json['rol'] as String,
      telefono: json['telefono'] as String?,
      activo: _parsearActivo(json['activo']),
      sancionesActivas:
          (json['sanciones_activas_count'] as num?)?.toInt() ??
          (json['sanciones_activas'] as num?)?.toInt() ??
          0,
      suspendidoHasta: json['suspendido_hasta'] != null
          ? DateTime.tryParse(json['suspendido_hasta'].toString())
          : null,
    );
  }

  static bool? _parsearActivo(Object? valor) {
    if (valor == null) return null;
    if (valor is bool) return valor;
    if (valor is num) return valor != 0;
    if (valor is String) {
      final normalizado = valor.trim().toLowerCase();
      if (normalizado == '1' || normalizado == 'true') return true;
      if (normalizado == '0' || normalizado == 'false') return false;
    }
    return null;
  }

  final int id;
  final String nombre;
  final String apellido;
  final String email;
  final String? telefono;
  final bool? activo;
  final int sancionesActivas;
  final DateTime? suspendidoHasta;

  /// `ciudadano`, `empleado` o `admin`, igual que en la base de datos[cite: 1].
  final String rol;

  bool get esOperario => rol == 'empleado';

  bool get esAdmin => rol == 'admin';

  bool get estaSuspendido {
    if (suspendidoHasta == null) return false;
    return suspendidoHasta!.isAfter(DateTime.now());
  }

  /// Nombre del rol para mostrar en pantalla.
  String get rolParaMostrar => switch (rol) {
    'empleado' => 'Operario',
    'admin' => 'Administrador',
    _ => 'Vecino',
  };
}
