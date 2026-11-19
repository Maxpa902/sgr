/// Datos de un reclamo mostrados en el listado de administración.
class ReclamoAdmin {
  const ReclamoAdmin({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.estado,
    required this.creador,
    required this.emailCreador,
    required this.creadoEn,
    this.descripcion,
    this.direccion,
    this.latitud,
    this.longitud,
    this.tipoIcono,
    required this.confirmacionesCount,
    required this.desmentidasCount,
  });

factory ReclamoAdmin.fromJson(Map<String, dynamic> json) => ReclamoAdmin(
    id: json['id'] as int,
    titulo: json['titulo'] as String,
    descripcion: json['descripcion'] as String?,
    direccion: json['direccion'] as String?,
    tipo: json['tipo'] as String,
    estado: json['estado'] as String,
    creador: json['creador'] as String? ?? '',
    emailCreador: json['email_creador'] as String? ?? '',
    creadoEn: DateTime.parse(json['creado_en'] as String),
    latitud: (json['latitud'] as num?)?.toDouble(),
    longitud: (json['longitud'] as num?)?.toDouble(),
    tipoIcono: json['tipo_icono'] as String?,
    confirmacionesCount: json['confirmaciones_count'] != null ? (json['confirmaciones_count'] as num).toInt() : 0,
    desmentidasCount: json['desmentidas_count'] != null ? (json['desmentidas_count'] as num).toInt() : 0,
  );

  final int id;
  final String titulo;
  final String? descripcion;
  final String? direccion;
  final String tipo;
  final String estado;
  final String creador;
  final String emailCreador;
  final DateTime creadoEn;
  final double? latitud;
  final double? longitud;
  final String? tipoIcono;
  final int confirmacionesCount;
  final int desmentidasCount;
}
