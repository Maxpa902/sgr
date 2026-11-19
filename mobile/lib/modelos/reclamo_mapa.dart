import 'tipo_reclamo.dart';

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
  });

  factory ReclamoMapa.fromJson(Map<String, dynamic> json) {
    final fotosJson = json['fotos'];
    final List<String> fotosLista = (fotosJson is List)
        ? fotosJson.map((e) => e.toString()).toList()
        : const [];

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

  // CAMBIO
  int get puntajeNeto => confirmaciones - desmentidas;
  bool get destacado => puntajeNeto >= destacadoDesde;
}
