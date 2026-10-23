import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../modelos/reclamo_admin.dart';
import '../modelos/tipo_reclamo.dart';
import '../sesion/sesion.dart';

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
    } on Object {
      // La lista de reclamos sigue siendo útil si no se pudo cargar el filtro.
    }
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
        _errorMas != null)
      return;

    final version = _versionConsulta;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await widget.sesion.listarReclamosAdmin(
        busqueda: _busqueda.text.trim(),
        estado: _filtroEstado == 'todos' ? null : _filtroEstado,
        tipoId: _filtroTipo == 'todos' ? null : int.tryParse(_filtroTipo),
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

  void _limpiarFiltros() {
    _actualizandoFiltros = true;
    _busqueda.clear();
    _filtroEstado = 'todos';
    _filtroTipo = 'todos';
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
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('Reclamos'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                children: [
                  FTextField(
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
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
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
    );
  }

  bool get _hayFiltros =>
      _busqueda.text.trim().isNotEmpty ||
      _filtroEstado != 'todos' ||
      _filtroTipo != 'todos';

  Widget _contenido(BuildContext context) {
    if (_cargandoInicial && _reclamos.isEmpty)
      return const Center(child: FCircularProgress());
    if (_errorInicial != null && _reclamos.isEmpty) {
      return _EstadoReclamos(
        icono: Icons.cloud_off_outlined,
        titulo: 'No se pudo cargar',
        detalle: _errorInicial!,
        accion: FButton(
          onPress: () => unawaited(_recargar()),
          prefix: const Icon(Icons.refresh),
          child: const Text('Reintentar'),
        ),
      );
    }
    if (!_cargandoInicial && _reclamos.isEmpty) {
      return _EstadoReclamos(
        icono: _hayFiltros ? Icons.search_off : Icons.assignment_outlined,
        titulo: _hayFiltros ? 'Sin resultados' : 'No hay reclamos',
        detalle: _hayFiltros ? 'Probá cambiar la búsqueda o los filtros.' : '',
        accion: _hayFiltros
            ? FButton(
                variant: .ghost,
                onPress: _limpiarFiltros,
                child: const Text('Limpiar filtros'),
              )
            : FButton(
                variant: .outline,
                onPress: () => unawaited(_recargar()),
                prefix: const Icon(Icons.refresh),
                child: const Text('Actualizar'),
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
          if (index < _reclamos.length)
            return _ReclamoTile(reclamo: _reclamos[index]);
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
  const _ReclamoTile({required this.reclamo});

  final ReclamoAdmin reclamo;

  @override
  Widget build(BuildContext context) {
    final muted = context.theme.colors.mutedForeground;
    final fecha = reclamo.creadoEn.toLocal();
    final fechaTexto =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  reclamo.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              FBadge(
                variant: .outline,
                child: Text(_estadoParaMostrar(reclamo.estado)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${reclamo.tipo} · $fechaTexto', style: TextStyle(color: muted)),
          if (reclamo.creador.isNotEmpty ||
              reclamo.emailCreador.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              [
                reclamo.creador,
                reclamo.emailCreador,
              ].where((dato) => dato.isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted),
            ),
          ],
          if ((reclamo.direccion ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              reclamo.direccion!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted),
            ),
          ],
        ],
      ),
    );
  }

  String _estadoParaMostrar(String estado) => switch (estado) {
    'pendiente' => 'Pendiente',
    'en_proceso' => 'En proceso',
    'resuelto' => 'Resuelto',
    'rechazado' => 'Rechazado',
    _ => estado,
  };
}

class _EstadoReclamos extends StatelessWidget {
  const _EstadoReclamos({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.accion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget accion;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 40, color: context.theme.colors.mutedForeground),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 20),
          accion,
        ],
      ),
    ),
  );
}
