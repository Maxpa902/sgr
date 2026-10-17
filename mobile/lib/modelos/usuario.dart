/// Una cuenta del sistema, tal como la devuelve el server.
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.rol,
    this.telefono,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      email: json['email'] as String,
      rol: json['rol'] as String,
      telefono: json['telefono'] as String?,
    );
  }

  final int id;
  final String nombre;
  final String apellido;
  final String email;
  final String? telefono;

  /// `ciudadano`, `empleado` o `admin`, igual que en la base de datos.
  final String rol;

  bool get esOperario => rol == 'empleado';

  bool get esAdmin => rol == 'admin';

  /// Nombre del rol para mostrar en pantalla.
  String get rolParaMostrar => switch (rol) {
    'empleado' => 'Operario',
    'admin' => 'Administrador',
    _ => 'Vecino',
  };
}
