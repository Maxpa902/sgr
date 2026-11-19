import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../modelos/usuario.dart';
import '../sesion/sesion.dart';
import '../tema/tema_app.dart';
import '../widgets/componentes_ui.dart';
import '../widgets/vecinos_sanciones_page.dart';
import 'crear_cuenta_interna_page.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final List<Usuario> _usuarios = [];
  final Set<int> _cambiandoEstado = <int>{};
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

  int _prioridadRol(String rol) {
    final normalizado = rol.trim().toLowerCase();
    if (normalizado == 'admin' || normalizado == 'administrador') return 0;
    if (normalizado == 'empleado' || normalizado == 'operario') return 1;
    return 2;
  }

  int _compararUsuarios(Usuario a, Usuario b) {
    final porRol = _prioridadRol(a.rol).compareTo(_prioridadRol(b.rol));
    if (porRol != 0) return porRol;

    final nombreA = '${a.apellido} ${a.nombre}'.trim().toLowerCase();
    final nombreB = '${b.apellido} ${b.nombre}'.trim().toLowerCase();
    return nombreA.compareTo(nombreB);
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  Future<void> _crearCuenta() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TemaApp(child: CrearCuentaInternaPage(sesion: widget.sesion)),
      ),
    );
    if (creada == true && mounted) {
      _mostrarMensaje('Cuenta creada correctamente.');
      await _recargar();
    }
  }

  Future<void> _alternarActivo(Usuario usuario, bool nuevoValor) async {
    if (_cambiandoEstado.contains(usuario.id)) return;

    setState(() => _cambiandoEstado.add(usuario.id));
    try {
      await widget.sesion.actualizarCuenta(
        usuario.id,
        activo: nuevoValor,
      );
      if (!mounted) return;
      _mostrarMensaje(
        nuevoValor ? 'Cuenta activada.' : 'Cuenta desactivada.',
      );
      await _recargar();
    } on ApiException catch (e) {
      _mostrarMensaje(
        e.statusCode != null ? '(${e.statusCode}) ${e.mensaje}' : e.mensaje,
      );
    } catch (e) {
      _mostrarMensaje('No se pudo actualizar el estado: $e');
    } finally {
      if (mounted) {
        setState(() => _cambiandoEstado.remove(usuario.id));
      }
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
      if (!mounted || version != _versionConsulta) return;

      setState(() {
        _usuarios
          ..clear()
          ..addAll(pagina.usuarios)
          ..sort(_compararUsuarios);
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
      if (!mounted || version != _versionConsulta) return;

      setState(() {
        _usuarios
          ..addAll(pagina.usuarios)
          ..sort(_compararUsuarios);
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
            : 'No se pudieron cargar más cuentas.';
      });
    }
  }

  void _seleccionarRol(String valor) {
    if (_filtroRol == valor) return;
    setState(() => _filtroRol = valor);
    unawaited(_recargar());
  }

  void _seleccionarEstado(String valor) {
    if (_filtroEstado == valor) return;
    setState(() => _filtroEstado = valor);
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
    final colors = context.theme.colors;

    return Scaffold(
      body: LayoutPagina(
        titulo: 'Cuentas',
        alVolver: () => Navigator.of(context).pop(),
        superficie: SuperficiePagina.bordeABorde,
        contenido: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border(bottom: BorderSide(color: colors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FTextField(
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
                                  const Icon(Icons.search, size: 18),
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _crearCuenta,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.person_add_alt_1,
                                size: 20,
                                color: colors.primaryForeground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _BarraFiltroEstado(
                      valorActual: _filtroEstado,
                      alCambiar: _seleccionarEstado,
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ChipFiltroRol(
                            etiqueta: 'Todos',
                            activo: _filtroRol == 'todos',
                            alPresionar: () => _seleccionarRol('todos'),
                          ),
                          const SizedBox(width: 6),
                          _ChipFiltroRol(
                            etiqueta: 'Admin',
                            activo: _filtroRol == 'admin',
                            alPresionar: () => _seleccionarRol('admin'),
                          ),
                          const SizedBox(width: 6),
                          _ChipFiltroRol(
                            etiqueta: 'Operario',
                            activo: _filtroRol == 'empleado',
                            alPresionar: () => _seleccionarRol('empleado'),
                          ),
                          const SizedBox(width: 6),
                          _ChipFiltroRol(
                            etiqueta: 'Vecino',
                            activo: _filtroRol == 'ciudadano',
                            alPresionar: () => _seleccionarRol('ciudadano'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _cargandoInicial
                              ? 'Buscando…'
                              : '$_total $_etiquetaTotal',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.mutedForeground,
                          ),
                        ),
                        if (_hayFiltros)
                          GestureDetector(
                            onTap: _limpiarFiltros,
                            child: Text(
                              'Limpiar filtros',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ),
                      ],
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
        itemCount: _usuarios.length + (_hayMas || _errorMas != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index < _usuarios.length) {
            final usuario = _usuarios[index];
            return _UsuarioCard(
              usuario: usuario,
              esUsuarioActual: usuario.id == widget.sesion.usuario?.id,
              cambiandoEstado: _cambiandoEstado.contains(usuario.id),
              alCambiarActivo: (nuevoValor) =>
                  unawaited(_alternarActivo(usuario, nuevoValor)),
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

class _BarraFiltroEstado extends StatelessWidget {
  const _BarraFiltroEstado({
    required this.valorActual,
    required this.alCambiar,
  });

  final String valorActual;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    const opciones = [
      ('todos', 'Todas'),
      ('activa', 'Activas'),
      ('inactiva', 'Desactivadas'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < opciones.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Builder(
                builder: (_) {
                  final valor = opciones[i].$1;
                  final texto = opciones[i].$2;
                  final seleccionada = valorActual == valor;

                  return FTappable(
                    onPress: () => alCambiar(valor),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: seleccionada
                            ? colors.background
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: seleccionada
                            ? Border.all(color: colors.border)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        texto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              seleccionada ? FontWeight.w600 : FontWeight.w400,
                          color: seleccionada
                              ? colors.foreground
                              : colors.mutedForeground,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipFiltroRol extends StatelessWidget {
  const _ChipFiltroRol({
    required this.etiqueta,
    required this.activo,
    required this.alPresionar,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return FTappable(
      onPress: alPresionar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? colors.primary : colors.border,
          ),
        ),
        child: Text(
          etiqueta,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
            color: activo ? colors.primaryForeground : colors.foreground,
          ),
        ),
      ),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  const _UsuarioCard({
    required this.usuario,
    required this.esUsuarioActual,
    required this.cambiandoEstado,
    required this.alCambiarActivo,
  });

  final Usuario usuario;
  final bool esUsuarioActual;
  final bool cambiandoEstado;
  final ValueChanged<bool> alCambiarActivo;

  bool get _esOperarioOAdmin {
    final r = usuario.rol.trim().toLowerCase();
    return r == 'empleado' ||
        r == 'operario' ||
        r == 'admin' ||
        r == 'administrador';
  }

  @override
  Widget build(BuildContext context) {
    final nombre = '${usuario.nombre} ${usuario.apellido}'.trim();
    final colores = context.theme.colors;
    final estaActiva = usuario.activo ?? true;
    final mostrarSwitch = _esOperarioOAdmin && !esUsuarioActual;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colores.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colores.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FBadge(
                      variant: .outline,
                      child: Text(
                        esUsuarioActual
                            ? '${usuario.rolParaMostrar} (Vos)'
                            : usuario.rolParaMostrar,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  usuario.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colores.mutedForeground,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: estaActiva
                          ? Colors.green.shade600
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      estaActiva ? 'Activa' : 'Inactiva',
                      style: TextStyle(
                        color: estaActiva
                            ? Colors.green.shade700
                            : colores.mutedForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (mostrarSwitch) ...[
            const SizedBox(width: 10),
            Material(
              type: MaterialType.transparency,
              child: Switch(
                value: estaActiva,
                activeColor: Colors.green.shade600,
                activeTrackColor: Colors.green.shade200,
                inactiveThumbColor: Colors.grey.shade600,
                inactiveTrackColor: Colors.grey.shade300,
                onChanged: cambiandoEstado ? null : alCambiarActivo,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
