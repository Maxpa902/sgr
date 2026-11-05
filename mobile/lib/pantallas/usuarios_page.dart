import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../modelos/usuario.dart';
import '../sesion/sesion.dart';
import '../widgets/componentes_ui.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final List<Usuario> _usuarios = [];
  final _busqueda = TextEditingController();
  final _scrollController = ScrollController();
  String _filtroRol = 'todos';
  String _filtroEstado = 'todos';
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
    unawaited(_cargarPrimeraPagina(++_versionConsulta));
  }

  void _alCambiarBusqueda(TextEditingValue valor) {
    if (_actualizandoFiltros) {
      return;
    }
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
      _usuarios.clear();
      _cursor = null;
      _total = 0;
      _hayMas = true;
      _cargandoInicial = true;
      _cargandoMas = false;
      _errorInicial = null;
      _errorMas = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    return version;
  }

  Future<void> _recargar() async {
    _debounce?.cancel();
    await _cargarPrimeraPagina(_prepararNuevaConsulta());
  }

  Future<void> _cargarPrimeraPagina(int version) async {
    try {
      final pagina = await widget.sesion.listarUsuarios(
        busqueda: _busqueda.text.trim(),
        rol: _filtroRol == 'todos' ? null : _filtroRol,
        estado: _filtroEstado == 'todos' ? null : _filtroEstado,
      );
      if (!mounted || version != _versionConsulta) {
        return;
      }
      setState(() {
        _usuarios
          ..clear()
          ..addAll(pagina.usuarios);
        _total = pagina.total;
        _cursor = pagina.proximoCursor;
        _hayMas = _cursor != null;
        _cargandoInicial = false;
        _errorInicial = null;
      });
      _cargarMasSiHaceFalta();
    } on Object catch (error) {
      if (!mounted || version != _versionConsulta) {
        return;
      }
      setState(() {
        _cargandoInicial = false;
        _errorInicial = error is ApiException
            ? error.mensaje
            : 'No se pudieron cargar las cuentas.';
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
      final pagina = await widget.sesion.listarUsuarios(
        busqueda: _busqueda.text.trim(),
        rol: _filtroRol == 'todos' ? null : _filtroRol,
        estado: _filtroEstado == 'todos' ? null : _filtroEstado,
        cursor: cursor,
      );
      if (!mounted || version != _versionConsulta) {
        return;
      }
      setState(() {
        _usuarios.addAll(pagina.usuarios);
        _total = pagina.total;
        _cursor = pagina.proximoCursor;
        _hayMas = _cursor != null;
        _cargandoMas = false;
        _errorMas = null;
      });
      _cargarMasSiHaceFalta();
    } on Object catch (error) {
      if (!mounted || version != _versionConsulta) {
        return;
      }
      setState(() {
        _cargandoMas = false;
        _errorMas = error is ApiException
            ? error.mensaje
            : 'No se pudieron cargar más cuentas.';
      });
    }
  }

  void _cambiarRol(String? valor) {
    setState(() => _filtroRol = valor ?? 'todos');
    unawaited(_recargar());
  }

  void _cambiarEstado(String? valor) {
    setState(() => _filtroEstado = valor ?? 'todos');
    unawaited(_recargar());
  }

  void _limpiarFiltros() {
    _actualizandoFiltros = true;
    _busqueda.clear();
    _filtroRol = 'todos';
    _filtroEstado = 'todos';
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
    return LayoutPagina(
      titulo: 'Cuentas',
      alVolver: () => Navigator.of(context).pop(),
      superficie: SuperficiePagina.bordeABorde,
      contenido: SafeArea(
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
                    hint: 'Buscar por nombre o correo',
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
                          hint: 'Todos los roles',
                          items: const {
                            'Todos los roles': 'todos',
                            'Vecino': 'ciudadano',
                            'Operario': 'empleado',
                            'Administrador': 'admin',
                          },
                          control: FSelectControl<String>.lifted(
                            value: _filtroRol,
                            onChange: _cambiarRol,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FSelect<String>(
                          hint: 'Todos los estados',
                          items: const {
                            'Todos los estados': 'todos',
                            'Activas': 'activa',
                            'Inactivas': 'inactiva',
                          },
                          control: FSelectControl<String>.lifted(
                            value: _filtroEstado,
                            onChange: _cambiarEstado,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _cargandoInicial
                            ? 'Buscando…'
                            : '$_total $_etiquetaTotal',
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
      _filtroRol != 'todos' ||
      _filtroEstado != 'todos';

  String get _etiquetaTotal {
    if (_hayFiltros) {
      return _total == 1 ? 'resultado' : 'resultados';
    }
    return _total == 1 ? 'cuenta' : 'cuentas';
  }

  Widget _contenido(BuildContext context) {
    if (_cargandoInicial && _usuarios.isEmpty) {
      return const Center(child: FCircularProgress());
    }
    if (_errorInicial != null && _usuarios.isEmpty) {
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
    if (!_cargandoInicial && _usuarios.isEmpty) {
      return EstadoContenido(
        tipo: _hayFiltros
            ? EstadoContenidoTipo.sinResultados
            : EstadoContenidoTipo.vacio,
        titulo: _hayFiltros ? 'Sin resultados' : 'No hay cuentas',
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
        itemCount: _usuarios.length + (_hayMas || _errorMas != null ? 1 : 0),
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: context.theme.colors.border),
        itemBuilder: (context, index) {
          if (index < _usuarios.length) {
            return _UsuarioTile(usuario: _usuarios[index]);
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

class _UsuarioTile extends StatelessWidget {
  const _UsuarioTile({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final nombre = '${usuario.nombre} ${usuario.apellido}'.trim();
    final colores = context.theme.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              FBadge(variant: .outline, child: Text(usuario.rolParaMostrar)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            usuario.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colores.mutedForeground),
          ),
          if (usuario.activo != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: usuario.activo!
                      ? colores.primary
                      : colores.destructive,
                ),
                const SizedBox(width: 6),
                Text(
                  usuario.activo! ? 'Activa' : 'Inactiva',
                  style: TextStyle(
                    color: colores.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
