import 'tipo_reclamo.dart';

/// Datos completos de un reclamo que consulta el panel administrativo.
class ReclamoDetalleAdmin {
  const ReclamoDetalleAdmin({
    required this.id,
    required this.titulo,
    required this.latitud,
    required this.longitud,
    required this.tipo,
    required this.estado,
    required this.creador,
    required this.emailCreador,
    required this.creadoEn,
    required this.fotos,
    required this.sancionesActivasCount,
    this.descripcion,
    this.direccion,
    this.responsable,
    this.cierre,
    this.asignadoPor,
    this.asignadoEn,
    this.ultimaDesasignacion,
    this.historial,
  });

  factory ReclamoDetalleAdmin.fromJson(Map<String, dynamic> json) {
    final fotosJson = json['fotos'];

    // Si el JSON trae los datos del usuario creador (o un campo plano)
    // Ajusta según cómo te devuelva Laravel el conteo (ej: json['sanciones_activas_count'] o dentro de un objeto 'usuario')
    final usuarioJson = json['usuario'] is Map<String, dynamic> ? json['usuario'] as Map<String, dynamic> : json;

    return ReclamoDetalleAdmin(
      id: json['id'] as int,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String?,
      direccion: json['direccion'] as String?,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      tipo: TipoReclamo.fromJson(json['tipo'] as Map<String, dynamic>),
      estado: json['estado'] as String,
      creador: json['creador'] as String? ?? '',
      emailCreador: json['email_creador'] as String? ?? '',
      creadoEn: DateTime.parse(json['creado_en'] as String),
      fotos: fotosJson is List
          ? fotosJson.map((foto) => foto.toString()).toList(growable: false)
          : const [],

      sancionesActivasCount: (usuarioJson['sanciones_activas_count'] ?? json['sanciones_activas_count']) as int? ?? 0,
      responsable: json['responsable'] is Map<String, dynamic>
          ? ResponsableReclamo.fromJson(
              json['responsable'] as Map<String, dynamic>,
            )
          : null,
      cierre: json['cierre'] is Map<String, dynamic>
          ? CierreReclamo.fromJson(json['cierre'] as Map<String, dynamic>)
          : null,
      asignadoPor: json['asignado_por'] is Map<String, dynamic>
          ? ResponsableReclamo.fromJson(
              json['asignado_por'] as Map<String, dynamic>,
            )
          : null,
      asignadoEn: json['asignado_en'] is String
          ? DateTime.tryParse(json['asignado_en'] as String)
          : null,
      ultimaDesasignacion: json['ultima_desasignacion'] is Map<String, dynamic>
          ? UltimaDesasignacion.fromJson(
              json['ultima_desasignacion'] as Map<String, dynamic>,
            )
          : null,
      historial: json['historial'] is List
          ? (json['historial'] as List)
                .whereType<Map<String, dynamic>>()
                .map(EventoEstadoReclamo.fromJson)
                .toList(growable: false)
          : null,
    );
  }

  final int id;
  final String titulo;
  final String? descripcion;
  final String? direccion;
  final double latitud;
  final double longitud;
  final TipoReclamo tipo;
  final String estado;
  final String creador;
  final String emailCreador;
  final DateTime creadoEn;
  final List<String> fotos;
  final int sancionesActivasCount;
  final ResponsableReclamo? responsable;
  final CierreReclamo? cierre;
  final ResponsableReclamo? asignadoPor;
  final DateTime? asignadoEn;
  final UltimaDesasignacion? ultimaDesasignacion;

  /// Null indica que el servidor no incluyó el historial en la respuesta.
  final List<EventoEstadoReclamo>? historial;
}

class EventoEstadoReclamo {
  const EventoEstadoReclamo({
    required this.id,
    required this.estado,
    required this.creadoEn,
    required this.visibilidad,
    this.autor,
    this.observacion,
  });

  factory EventoEstadoReclamo.fromJson(Map<String, dynamic> json) =>
      EventoEstadoReclamo(
        id: json['id'] as int,
        estado: json['estado'] as String,
        creadoEn: DateTime.parse(json['creado_en'] as String),
        visibilidad: json['visibilidad'] as String? ?? 'publica',
        observacion: json['observacion'] as String?,
        autor: json['autor'] is Map<String, dynamic>
            ? ResponsableReclamo.fromJson(json['autor'] as Map<String, dynamic>)
            : null,
      );

  final int id;
  final String estado;
  final DateTime creadoEn;
  final String visibilidad;
  final String? observacion;
  final ResponsableReclamo? autor;
}

class UltimaDesasignacion {
  const UltimaDesasignacion({
    required this.responsable,
    required this.creadoEn,
    this.autor,
  });

  factory UltimaDesasignacion.fromJson(Map<String, dynamic> json) =>
      UltimaDesasignacion(
        responsable: ResponsableReclamo.fromJson(
          json['responsable'] as Map<String, dynamic>,
        ),
        creadoEn: DateTime.parse(json['creado_en'] as String),
        autor: json['autor'] is Map<String, dynamic>
            ? ResponsableReclamo.fromJson(json['autor'] as Map<String, dynamic>)
            : null,
      );

  final ResponsableReclamo responsable;
  final ResponsableReclamo? autor;
  final DateTime creadoEn;
}

class ResponsableReclamo {
  const ResponsableReclamo({
    required this.id,
    required this.nombre,
    required this.apellido,
  });

  factory ResponsableReclamo.fromJson(Map<String, dynamic> json) =>
      ResponsableReclamo(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        apellido: json['apellido'] as String,
      );

  final int id;
  final String nombre;
  final String apellido;

  String get nombreCompleto => '$nombre $apellido'.trim();
}

class CierreReclamo {
  const CierreReclamo({required this.creadoEn, this.observacion, this.autor});

  factory CierreReclamo.fromJson(Map<String, dynamic> json) => CierreReclamo(
    creadoEn: DateTime.parse(json['creado_en'] as String),
    observacion: json['observacion'] as String?,
    autor: json['autor'] is Map<String, dynamic>
        ? ResponsableReclamo.fromJson(json['autor'] as Map<String, dynamic>)
        : null,
  );

  final DateTime creadoEn;
  final String? observacion;
  final ResponsableReclamo? autor;
}
