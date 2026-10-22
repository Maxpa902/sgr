import 'tipo_reclamo.dart';

/// Los datos de un reclamo que hacen falta para dibujar su pin en el mapa y mostrar su resumen.
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
    this.descripcion,
    this.direccion,
    this.fotos = const [],
  });

  factory ReclamoMapa.fromJson(Map<String, dynamic> json) {
    // Extracción segura de la lista de fotos sin riesgo de devolver nulo
    final fotosJson = json['fotos'];
    final List<String> fotosLista = (fotosJson is List)
        ? fotosJson.map((e) => e.toString()).toList()
        : const [];

    return ReclamoMapa(
      id: json['id'] as int,
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

  /// A partir de cuántas confirmaciones un reclamo se destaca en el mapa.
  static const destacadoDesde = 5;

  final int id;
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

  bool get destacado => confirmaciones >= destacadoDesde;
}