/// Un comentario de un reclamo.
class Comentario {
  const Comentario({
    required this.id,
    required this.contenido,
    required this.autor,
    required this.esMio,
    required this.editado,
    required this.creadoEn,
  });

  factory Comentario.fromJson(Map<String, dynamic> json) {
    return Comentario(
      id: json['id'] as int,
      contenido: json['contenido'] as String,
      autor: json['autor'] as String,
      esMio: json['es_mio'] as bool? ?? false,
      editado: json['editado'] as bool? ?? false,
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }

  final int id;
  final String contenido;

  /// Nombre y apellido de quien lo escribió.
  final String autor;

  /// Lo escribió el usuario de la sesión.
  final bool esMio;
  final bool editado;
  final DateTime creadoEn;
}

/// Los comentarios de un reclamo y lo que el usuario puede hacer con ellos.
class ComentariosDeReclamo {
  const ComentariosDeReclamo({
    required this.comentarios,
    required this.disponibles,
    required this.puedeModificarPropios,
    this.motivoBloqueo,
  });

  factory ComentariosDeReclamo.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List? ?? const [];
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return ComentariosDeReclamo(
      comentarios: data
          .whereType<Map<String, dynamic>>()
          .map(Comentario.fromJson)
          .toList(growable: false),
      disponibles: (meta['disponibles'] as num?)?.toInt() ?? 0,
      motivoBloqueo: meta['motivo_bloqueo'] as String?,
      puedeModificarPropios: meta['puede_modificar_propios'] as bool? ?? false,
    );
  }

  /// Del más viejo al más nuevo.
  final List<Comentario> comentarios;

  /// Cuántos comentarios más puede escribir el usuario (de 0 a 3).
  final int disponibles;

  /// Por qué no puede escribir otro comentario; `null` si puede.
  final String? motivoBloqueo;

  /// Puede editar o borrar los suyos (el límite de 3 no cuenta para esto).
  final bool puedeModificarPropios;

  bool get puedeComentar => motivoBloqueo == null;
}
