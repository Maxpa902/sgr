import 'tipo_reclamo.dart';

class FotoReclamo {
  const FotoReclamo({required this.id, required this.url});

  final int id;
  final String url;
}

/// Los datos de un reclamo para el mapa y su detalle.
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
    this.usuarioId,
    this.miVoto,
    this.descripcion,
    this.direccion,
    this.fotos = const [],
    this.fotosDetalle = const [],
  });

  factory ReclamoMapa.fromJson(Map<String, dynamic> json) {
    final fotosJson = json['fotos'];
    final List<String> fotosLista = (fotosJson is List)
        ? fotosJson.map((e) => e.toString()).toList()
        : const [];

    final fotosDetalleJson = json['fotos_detalle'];
    final List<FotoReclamo> detalleLista = [
      if (fotosDetalleJson is List)
        for (final f in fotosDetalleJson)
          if (f is Map<String, dynamic>)
            FotoReclamo(
              id: f['id'] as int,
              url: f['url'] as String,
            ),
    ];

    return ReclamoMapa(
      id: json['id'] as int,
      usuarioId: json['usuario_id'] as int?,
      miVoto: json['mi_voto'] as String?,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String?,
      latitud: double.parse(json['latitud'].toString()),
      longitud: double.parse(json['longitud'].toString()),
      estado: json['estado'] as String? ?? 'pendiente',
      confirmaciones:
          int.tryParse(json['confirmaciones']?.toString() ?? '0') ?? 0,
      desmentidas: int.tryParse(json['desmentidas']?.toString() ?? '0') ?? 0,
      creadoEn: DateTime.parse(
        (json['creado_en'] ?? json['created_at']) as String,
      ),
      tipo: TipoReclamo.fromJson(json['tipo'] as Map<String, dynamic>),
      direccion: json['direccion'] as String?,
      fotos: fotosLista,
      fotosDetalle: detalleLista,
    );
  }

  static const destacadoDesde = 5;

  final int id;
  final int? usuarioId;
  final String? miVoto; // 'confirma', 'desmiente' o null
  final String titulo;
  final String? descripcion;
  final double latitud;
  final double longitud;
  final String? direccion;
  final TipoReclamo tipo;
  final String estado;
  final int confirmaciones;
  final int desmentidas;
  final DateTime creadoEn;
  final List<String> fotos;
  final List<FotoReclamo> fotosDetalle;

  int get puntajeNeto => confirmaciones - desmentidas;
  bool get destacado => puntajeNeto >= destacadoDesde;
}