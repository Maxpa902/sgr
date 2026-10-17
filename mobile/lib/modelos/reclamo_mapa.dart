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
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      direccion: json['direccion'] as String?,
      tipo: TipoReclamo.fromJson(json['tipo'] as Map<String, dynamic>),
      estado: json['estado'] as String,
      confirmaciones: json['confirmaciones'] as int,
      desmentidas: json['desmentidas'] as int,
      creadoEn: DateTime.parse(json['created_at'] as String).toLocal(),
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
