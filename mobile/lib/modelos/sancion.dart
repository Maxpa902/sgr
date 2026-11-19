/// Una sanción por reclamo falso: suspende al vecino 30 días desde el rechazo.
class Sancion {
  const Sancion({
    required this.id,
    required this.tituloReclamo,
    required this.activa,
    required this.creadaEn,
    required this.terminaEn,
    this.revocadaEn,
    this.revocadaPor,
    this.motivoRevocacion,
  });

  factory Sancion.fromJson(Map<String, dynamic> json) {
    final reclamo = json['reclamo'] as Map<String, dynamic>?;
    final revocadaPor = json['revocada_por'] as Map<String, dynamic>?;
    return Sancion(
      id: json['id'] as int,
      tituloReclamo: reclamo?['titulo'] as String? ?? 'Reclamo no disponible',
      activa: json['activa'] as bool,
      creadaEn: DateTime.parse(json['creada_en'] as String),
      terminaEn: DateTime.parse(json['termina_en'] as String),
      revocadaEn: json['revocada_en'] == null
          ? null
          : DateTime.parse(json['revocada_en'] as String),
      revocadaPor: revocadaPor == null
          ? null
          : '${revocadaPor['nombre']} ${revocadaPor['apellido']}',
      motivoRevocacion: json['motivo_revocacion'] as String?,
    );
  }

  final int id;
  final String tituloReclamo;

  /// No fue revocada y sus 30 días todavía no pasaron.
  final bool activa;
  final DateTime creadaEn;
  final DateTime terminaEn;
  final DateTime? revocadaEn;

  /// Nombre y apellido del admin que la revocó.
  final String? revocadaPor;
  final String? motivoRevocacion;

  bool get revocada => revocadaEn != null;
}

/// Las sanciones de un vecino y hasta cuándo está suspendido.
class SancionesDeVecino {
  const SancionesDeVecino({required this.sanciones, this.suspendidoHasta});

  factory SancionesDeVecino.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'] as Map<String, dynamic>? ?? const {};
    final data = json['data'] as List? ?? const [];
    return SancionesDeVecino(
      sanciones: data
          .whereType<Map<String, dynamic>>()
          .map(Sancion.fromJson)
          .toList(growable: false),
      suspendidoHasta: usuario['suspendido_hasta'] == null
          ? null
          : DateTime.parse(usuario['suspendido_hasta'] as String),
    );
  }

  /// De la más nueva a la más vieja.
  final List<Sancion> sanciones;
  final DateTime? suspendidoHasta;

  bool get estaSuspendido =>
      suspendidoHasta != null && suspendidoHasta!.isAfter(DateTime.now());
}
