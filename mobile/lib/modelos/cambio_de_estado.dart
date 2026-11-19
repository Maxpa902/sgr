/// Un cambio de estado de un reclamo, tal como lo ve cualquier vecino.
///
/// El server no manda quién hizo el cambio ni las observaciones internas.
class CambioDeEstado {
  const CambioDeEstado({
    required this.estado,
    required this.creadoEn,
    this.observacion,
  });

  factory CambioDeEstado.fromJson(Map<String, dynamic> json) {
    return CambioDeEstado(
      estado: json['estado'] as String,
      observacion: json['observacion'] as String?,
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }

  /// `pendiente`, `en_proceso`, `resuelto` o `rechazado`.
  final String estado;

  /// Solo si la observación es pública.
  final String? observacion;
  final DateTime creadoEn;
}
