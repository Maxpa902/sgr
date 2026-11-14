import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../modelos/reclamo_admin.dart';
import '../modelos/tipo_reclamo.dart';
import '../sesion/sesion.dart';
import '../tema/tema_app.dart';
import '../widgets/componentes_ui.dart';
import 'detalle_reclamo_admin_page.dart';
import '../widgets/vecinos_sanciones_page.dart';

class ReclamosAdminPage extends StatefulWidget {
  const ReclamosAdminPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<ReclamosAdminPage> createState() => _ReclamosAdminPageState();
}

class _ReclamosAdminPageState extends State<ReclamosAdminPage> {
  static const _estados = <String, String>{
    'Pendientes': 'pendiente',
    'En proceso': 'en_proceso',
    'Resueltos': 'resuelto',
    'Rechazados': 'rechazado',
  };

  final List<ReclamoAdmin> _reclamos = [];
  final _busqueda = TextEditingController();
  final _scrollController = ScrollController();
  List<TipoReclamo> _tipos = [];
  String _filtroEstado = 'todos';
  String _filtroTipo = 'todos';
  bool _soloUrgentes = false;
  String? _cursor;
  String? _errorInicial;
  String? _errorMas;
  int _total = 0;
  int _versionConsulta = 0;
  bool _cargandoInicial = true;
  bool _cargandoMas = false;
  bool _hayMas = true;
  bool _actualizandoFiltros = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_alDesplazarse);
    unawaited(_cargarTipos());
    unawaited(_cargarPrimeraPagina(++_versionConsulta));
  }

  Future<void> _cargarTipos() async {
    try {
      final tipos = await widget.sesion.tiposDeReclamoAdmin();
      if (mounted) setState(() => _tipos = tipos);
    } on Object {}
  }

  void _alCambiarBusqueda(TextEditingValue valor) {
    if (_actualizandoFiltros) return;
    _debounce?.cancel();
    final version = _prepararNuevaConsulta();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_cargarPrimeraPagina(version)),
    );
  }

  int _prepararNuevaConsulta() {
    final version = ++_versionConsulta;
    setState(() {
      _reclamos.clear();
      _cursor = null;
      _total = 0;
      _hayMas = true;
      _cargandoInicial = true;
      _cargandoMas = false;
      _errorInicial = null;
      _errorMas = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    return version;
  }

  Future<void> _recargar() async {
    _debounce?.cancel();
    await _cargarPrimeraPagina(_prepararNuevaConsulta());
  }

  Future<void> _cargarPrimeraPagina(int version) async {
    try {
      final pagina = await widget.sesion.listarReclamosAdmin(
        busqueda: _busqueda.text.trim(),
        estado: _filtroEstado == 'todos' ? null : _filtroEstado,
        tipoId: _filtroTipo == 'todos' ? null : int.tryParse(_filtroTipo),
        urgentes: _soloUrgentes,
      );
      if (!mounted || version != _versionConsulta) return;
      setState(() {
        _reclamos
          ..clear()
          ..addAll(pagina.reclamos);
        _total = pagina.total;
        _cursor = pagina.proximoCursor;
        _hayMas = _cursor != null;
        _cargandoInicial = false;
        _errorInicial = null;
      });
      _cargarMasSiHaceFalta();
    } on Object catch (error) {
      if (!mounted || version != _versionConsulta) return;
      setState(() {
        _cargandoInicial = false;
        _errorInicial = error is ApiException
            ? error.mensaje
            : 'No se pudieron cargar los reclamos.';
      });
    }
  }

  void _alDesplazarse() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 420) {
      unawaited(_cargarMas());
    }
  }

  void _cargarMasSiHaceFalta() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scrollController.hasClients &&
          _scrollController.position.extentAfter < 420) {
        unawaited(_cargarMas());
      }
    });
  }

  Future<void> _cargarMas() async {
    final cursor = _cursor;
    if (!_hayMas ||
        cursor == null ||
        _cargandoInicial ||
        _cargandoMas ||
        _errorMas != null) {
      return;
    }

    final version = _versionConsulta;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await widget.sesion.listarReclamosAdmin(
        busqueda: _busqueda.text.trim(),
        estado: _filtroEstado == 'todos' ? null : _filtroEstado,
        tipoId: _filtroTipo == 'todos' ? null : int.tryParse(_filtroTipo),
        urgentes: _soloUrgentes,
        cursor: cursor,
      );
      if (!mounted || version != _versionConsulta) return;
      setState(() {
        _reclamos.addAll(pagina.reclamos);
        _total = pagina.total;
        _cursor = pagina.proximoCursor;
        _hayMas = _cursor != null;
        _cargandoMas = false;
        _errorMas = null;
      });
      _cargarMasSiHaceFalta();
    } on Object catch (error) {
      if (!mounted || version != _versionConsulta) return;
      setState(() {
        _cargandoMas = false;
        _errorMas = error is ApiException
            ? error.mensaje
            : 'No se pudieron cargar más reclamos.';
      });
    }
  }

  void _cambiarEstado(String? valor) {
    setState(() => _filtroEstado = valor ?? 'todos');
    unawaited(_recargar());
  }

  void _cambiarTipo(String? valor) {
    setState(() => _filtroTipo = valor ?? 'todos');
    unawaited(_recargar());
  }

  void _toggleUrgentes() {
    setState(() => _soloUrgentes = !_soloUrgentes);
    unawaited(_recargar());
  }

  void _limpiarFiltros() {
    _actualizandoFiltros = true;
    _busqueda.clear();
    _filtroEstado = 'todos';
    _filtroTipo = 'todos';
    _soloUrgentes = false;
    _actualizandoFiltros = false;
    unawaited(_recargar());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_alDesplazarse)
      ..dispose();
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutPagina(
        titulo: 'Reclamos',
        alVolver: () => Navigator.of(context).pop(),
        superficie: SuperficiePagina.bordeABorde,
        contenido: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FTextField(
                            control: FTextFieldControl.managed(
                              controller: _busqueda,
                              onChange: _alCambiarBusqueda,
                            ),
                            hint: 'Buscar reclamos',
                            clearable: (value) => value.text.isNotEmpty,
                            prefixBuilder: (context, style, variants) =>
                                FTextField.prefixIconBuilder(
                                  context,
                                  style,
                                  variants,
                                  const Icon(Icons.search),
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Filtrar reclamos urgentes (falsos/desmentidos)',
                          child: Material(
                            color: _soloUrgentes ? Colors.red.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: _toggleUrgentes,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _soloUrgentes ? Colors.red.shade400 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: _soloUrgentes ? Colors.red.shade800 : Colors.grey.shade600,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FSelect<String>(
                            hint: 'Todos los estados',
                            items: const {
                              'Todos los estados': 'todos',
                              ..._estados,
                            },
                            control: FSelectControl<String>.lifted(
                              value: _filtroEstado,
                              onChange: _cambiarEstado,
                            ),
                          ),
                        ),
                        if (_tipos.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: FSelect<String>(
                              hint: 'Todas las categorías',
                              items: {
                                'Todas las categorías': 'todos',
                                for (final tipo in _tipos)
                                  tipo.nombre: '${tipo.id}',
                              },
                              control: FSelectControl<String>.lifted(
                                value: _filtroTipo,
                                onChange: _cambiarTipo,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _cargandoInicial
                              ? 'Buscando…'
                              : '$_total ${_total == 1 ? 'reclamo' : 'reclamos'}',
                          style: TextStyle(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _contenido(context)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TemaApp(
                child: VecinosSancionesPage(sesion: widget.sesion),
              ),
            ),
          );
        },
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        elevation: 3,
        tooltip: 'Sanciones',
        child: const Icon(Icons.gavel_rounded, size: 24),
      ),
    );
  }

  bool get _hayFiltros =>
      _busqueda.text.trim().isNotEmpty ||
      _filtroEstado != 'todos' ||
      _filtroTipo != 'todos' ||
      _soloUrgentes;

  Widget _contenido(BuildContext context) {
    if (_cargandoInicial && _reclamos.isEmpty) {
      return const Center(child: FCircularProgress());
    }
    if (_errorInicial != null && _reclamos.isEmpty) {
      return EstadoContenido(
        tipo: EstadoContenidoTipo.error,
        titulo: 'No se pudo cargar',
        descripcion: _errorInicial!,
        icono: Icons.cloud_off_outlined,
        accion: AccionContenido(
          etiqueta: 'Reintentar',
          alActivar: () => unawaited(_recargar()),
        ),
      );
    }
    if (!_cargandoInicial && _reclamos.isEmpty) {
      return EstadoContenido(
        tipo: _hayFiltros
            ? EstadoContenidoTipo.sinResultados
            : EstadoContenidoTipo.vacio,
        titulo: _hayFiltros ? 'Sin resultados' : 'No hay reclamos',
        descripcion: _hayFiltros
            ? 'Probá cambiar la búsqueda o los filtros.'
            : null,
        accion: AccionContenido(
          etiqueta: _hayFiltros ? 'Limpiar filtros' : 'Actualizar',
          alActivar: _hayFiltros
              ? _limpiarFiltros
              : () => unawaited(_recargar()),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _reclamos.length + (_hayMas || _errorMas != null ? 1 : 0),
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: context.theme.colors.border),
        itemBuilder: (context, index) {
          if (index < _reclamos.length) {
            return _ReclamoTile(
              reclamo: _reclamos[index],
              sesion: widget.sesion,
              alVolver: _recargar,
            );
          }
          if (_errorMas != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FButton(
                  variant: .outline,
                  onPress: () {
                    setState(() => _errorMas = null);
                    unawaited(_cargarMas());
                  },
                  prefix: const Icon(Icons.refresh),
                  child: const Text('Reintentar carga'),
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: FCircularProgress()),
          );
        },
      ),
    );
  }
}

class _ReclamoTile extends StatelessWidget {
  const _ReclamoTile({
    required this.reclamo,
    required this.sesion,
    required this.alVolver,
  });

  final ReclamoAdmin reclamo;
  final Sesion sesion;
  final Future<void> Function() alVolver;

  @override
  Widget build(BuildContext context) {
    final fecha = reclamo.creadoEn.toLocal();
    final fechaTexto =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    return Stack(
      children: [
        FilaReclamo(
          titulo: reclamo.titulo,
          estado: reclamo.estado,
          metadatos: [
            reclamo.tipo,
            fechaTexto,
            reclamo.creador,
            reclamo.emailCreador,
            reclamo.direccion ?? '',
          ],
          alAbrir: () async {
            var huboCambios = false;
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TemaApp(
                  child: DetalleReclamoAdminPage(
                    sesion: sesion,
                    reclamoId: reclamo.id,
                    alCambiar: () => huboCambios = true,
                  ),
                ),
              ),
            );
            if (context.mounted && huboCambios) await alVolver();
          },
        ),
        Positioned(
          right: 10,
          top: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Círculo de desmentidos (Rojo)
              if (reclamo.desmentidasCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${reclamo.desmentidasCount}',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // Círculo de confirmaciones (Verde)
              if (reclamo.confirmacionesCount > 0)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${reclamo.confirmacionesCount}',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
