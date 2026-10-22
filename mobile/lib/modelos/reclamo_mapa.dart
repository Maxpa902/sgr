import 'tipo_reclamo.dart';

/// Los datos de un reclamo que hacen falta para dibujar su pin en el mapa.
class ReclamoMapa {
  const ReclamoMapa({
    required this.id,
    required this.titulo,
    required this.latitud,
    required this.longitud,
    required this.tipo,
    required this.estado,
    required this.confirmaciones,
    required this.desmentidas,
    required this.creadoEn,
    this.direccion,
  });

  factory ReclamoMapa.fromJson(Map<String, dynamic> json) {
  return ReclamoMapa(
    id: json['id'] as int,
    titulo: json['titulo'] as String,
    latitud: double.parse(json['latitud'].toString()),
    longitud: double.parse(json['longitud'].toString()),
    estado: json['estado'] as String? ?? 'pendiente',
    confirmaciones: int.tryParse(json['confirmaciones']?.toString() ?? '0') ?? 0,
    desmentidas: int.tryParse(json['desmentidas']?.toString() ?? '0') ?? 0,
    creadoEn: DateTime.parse(
      (json['creado_en'] ?? json['created_at']) as String,
    ),
    tipo: TipoReclamo.fromJson(json['tipo'] as Map<String, dynamic>),
    direccion: json['direccion'] as String?,
  );
}

  /// A partir de cuántas confirmaciones un reclamo se destaca en el mapa.
  static const destacadoDesde = 5;

  final int id;

  /// El título que escribió el vecino o, si no escribió, la categoría.
  final String titulo;
  final double latitud;
  final double longitud;
  final String? direccion;
  final TipoReclamo tipo;

  /// `pendiente`, `en_proceso`, `resuelto` o `rechazado`.
  final String estado;
  final int confirmaciones;
  final int desmentidas;
  final DateTime creadoEn;

  bool get destacado => confirmaciones >= destacadoDesde;
}
