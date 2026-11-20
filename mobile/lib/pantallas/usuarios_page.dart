import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../formato.dart';
import '../modelos/usuario.dart';
import '../pantallas/sanciones_vecino_page.dart';
import '../sesion/sesion.dart';
import '../tema/tema_app.dart';
import '../widgets/componentes_ui.dart';
import '../widgets/ui/notificaciones.dart';
import 'crear_cuenta_interna_page.dart';

enum _SeccionCuentas { personal, vecinosSanciones }

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  _SeccionCuentas _seccionActual = _SeccionCuentas.personal;

  // --- Estado sección Personal (Admin y Operarios) ---
  final List<Usuario> _personal = [];
  final _busquedaPersonal = TextEditingController();
  final _scrollPersonal = ScrollController();

  String _filtroRol = 'todos'; // 'todos', 'admin', 'empleado'
  String? _cursorPersonal;
  String? _errorInicialPersonal;
  String? _errorMasPersonal;
  int _versionConsultaPersonal = 0;
  bool _cargandoInicialPersonal = true;
  bool _cargandoMasPersonal = false;
  bool _hayMasPersonal = true;
  bool _actualizandoFiltrosPersonal = false;
  Timer? _debouncePersonal;

  // --- Estado sección Vecinos y Sanciones ---
  final List<Usuario> _vecinos = [];
  final Map<int, Usuario> _mapaConSanciones = {};
  final _busquedaVecinos = TextEditingController();
  final _scrollVecinos = ScrollController();

  String? _cursorVecinos;
  String? _errorInicialVecinos;
  String? _errorMasVecinos;
  int _totalVecinos = 0;
  int _versionConsultaVecinos = 0;
  bool _cargandoInicialVecinos = true;
  bool _cargandoMasVecinos = false;
  bool _hayMasVecinos = true;
  bool _actualizandoFiltrosVecinos = false;
  Timer? _debounceVecinos;

  @override
  void initState() {
    super.initState();
    _scrollPersonal.addListener(_alDesplazarsePersonal);
    _scrollVecinos.addListener(_alDesplazarseVecinos);
    unawaited(_cargarPrimeraPaginaPersonal(++_versionConsultaPersonal));
    unawaited(_cargarPrimeraPaginaVecinos(++_versionConsultaVecinos));
  }

  bool _esAdminOOperario(Usuario u) {
    final r = u.rol.trim().toLowerCase();
    return r == 'admin' ||
        r == 'administrador' ||
        r == 'empleado' ||
        r == 'operario';
  }

  int _prioridadRol(String rol) {
    final normalizado = rol.trim().toLowerCase();
    if (normalizado == 'admin' || normalizado == 'administrador') return 0;
    if (normalizado == 'empleado' || normalizado == 'operario') return 1;
    return 2;
  }

  int _compararPersonal(Usuario a, Usuario b) {
    final porRol = _prioridadRol(a.rol).compareTo(_prioridadRol(b.rol));
    if (porRol != 0) return porRol;

    final nombreA = '${a.apellido} ${a.nombre}'.trim().toLowerCase();
    final nombreB = '${b.apellido} ${b.nombre}'.trim().toLowerCase();
    return nombreA.compareTo(nombreB);
  }

  int _compararVecinos(Usuario a, Usuario b) {
    if (a.estaSuspendido != b.estaSuspendido) {
      return a.estaSuspendido ? -1 : 1;
    }
    final nombreA = '${a.apellido} ${a.nombre}'.trim().toLowerCase();
    final nombreB = '${b.apellido} ${b.nombre}'.trim().toLowerCase();
    return nombreA.compareTo(nombreB);
  }

  /// Reemplaza el usuario del listado general con la versión que trae los
  /// datos completos de suspensión si existe en [_mapaConSanciones].
  Usuario _combinarConSancion(Usuario vecino) {
    return _mapaConSanciones[vecino.id] ?? vecino;
  }

  void _mostrarMensaje(
    String mensaje, {
    TipoNotificacion tipo = TipoNotificacion.informacion,
    Object? id,
  }) {
    if (!mounted) return;
    Notificaciones.mostrar(
      context,
      tipo: tipo,
      mensaje: mensaje,
      id: id,
    );
  }

  // ===========================================================================
  // LÓGICA SECCIÓN 1: PERSONAL (ADMIN Y OPERARIOS)
  // ===========================================================================

  Future<void> _crearCuenta() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TemaApp(child: CrearCuentaInternaPage(sesion: widget.sesion)),
      ),
    );
    if (creada == true && mounted) {
      _mostrarMensaje(
        'Cuenta creada correctamente.',
        tipo: TipoNotificacion.exito,
        id: 'cuenta-creada',
      );
      await _recargarPersonal();
    }
  }

  Future<void> _abrirEditorPersonal(Usuario usuario) async {
    final colors = context.theme.colors;
    final rolActualNorm = usuario.rol.trim().toLowerCase();
    String rolSeleccionado =
        (rolActualNorm == 'admin' || rolActualNorm == 'administrador')
            ? 'admin'
            : 'empleado';
    bool activoSeleccionado = usuario.activo ?? true;
    bool guardando = false;

    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final nombreCompleto =
                '${usuario.nombre} ${usuario.apellido}'.trim();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Editar cuenta',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$nombreCompleto · ${usuario.email}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: guardando
                              ? null
                              : () => Navigator.of(ctx).pop(false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Rol',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _OpcionSelectorModal(
                            etiqueta: 'Administrador',
                            icono: Icons.admin_panel_settings_outlined,
                            seleccionado: rolSeleccionado == 'admin',
                            alPresionar: guardando
                                ? null
                                : () => setModalState(
                                      () => rolSeleccionado = 'admin',
                                    ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OpcionSelectorModal(
                            etiqueta: 'Operario',
                            icono: Icons.engineering_outlined,
                            seleccionado: rolSeleccionado == 'empleado',
                            alPresionar: guardando
                                ? null
                                : () => setModalState(
                                      () => rolSeleccionado = 'empleado',
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cuenta activa',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activoSeleccionado
                                      ? 'Puede iniciar sesión en el sistema'
                                      : 'Acceso bloqueado al sistema',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            type: MaterialType.transparency,
                            child: Switch(
                              value: activoSeleccionado,
                              activeColor: Colors.green.shade600,
                              activeTrackColor: Colors.green.shade200,
                              onChanged: guardando
                                  ? null
                                  : (val) => setModalState(
                                        () => activoSeleccionado = val,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FButton(
                            variant: .outline,
                            onPress: guardando
                                ? null
                                : () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FButton(
                            onPress: guardando
                                ? null
                                : () async {
                                    setModalState(() => guardando = true);
                                    try {
                                      await widget.sesion.actualizarCuenta(
                                        usuario.id,
                                        rol: rolSeleccionado,
                                        activo: activoSeleccionado,
                                      );
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop(true);
                                      }
                                    } on ApiException catch (e) {
                                      setModalState(() => guardando = false);
                                      _mostrarMensaje(
                                        e.statusCode != null
                                            ? '(${e.statusCode}) ${e.mensaje}'
                                            : e.mensaje,
                                        tipo: TipoNotificacion.error,
                                      );
                                    } catch (e) {
                                      setModalState(() => guardando = false);
                                      _mostrarMensaje(
                                        'No se pudieron guardar los cambios: $e',
                                        tipo: TipoNotificacion.error,
                                      );
                                    }
                                  },
                            child: guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: FCircularProgress(),
                                  )
                                : const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (guardado == true && mounted) {
      _mostrarMensaje(
        'Cuenta actualizada correctamente.',
        tipo: TipoNotificacion.exito,
        id: 'cuenta-editada',
      );
      await _recargarPersonal();
    }
  }

  void _alCambiarBusquedaPersonal(TextEditingValue valor) {
    if (_actualizandoFiltrosPersonal) return;
    _debouncePersonal?.cancel();
    final version = _prepararNuevaConsultaPersonal();
    _debouncePersonal = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_cargarPrimeraPaginaPersonal(version)),
    );
  }

  int _prepararNuevaConsultaPersonal() {
    final version = ++_versionConsultaPersonal;
    setState(() {
      _personal.clear();
      _cursorPersonal = null;
      _hayMasPersonal = true;
      _cargandoInicialPersonal = true;
      _cargandoMasPersonal = false;
      _errorInicialPersonal = null;
      _errorMasPersonal = null;
    });
    if (_scrollPersonal.hasClients) {
      _scrollPersonal.jumpTo(0);
    }
    return version;
  }

  Future<void> _recargarPersonal() async {
    _debouncePersonal?.cancel();
    await _cargarPrimeraPaginaPersonal(_prepararNuevaConsultaPersonal());
  }

  Future<void> _cargarPrimeraPaginaPersonal(int version) async {
    try {
      final pagina = await widget.sesion.listarUsuarios(
        busqueda: _busquedaPersonal.text.trim(),
        rol: _filtroRol == 'todos' ? null : _filtroRol,
      );
      if (!mounted || version != _versionConsultaPersonal) return;

      final soloInternos = pagina.usuarios.where(_esAdminOOperario).toList();

      setState(() {
        _personal
          ..clear()
          ..addAll(soloInternos)
          ..sort(_compararPersonal);
        _cursorPersonal = pagina.proximoCursor;
        _hayMasPersonal = _cursorPersonal != null;
        _cargandoInicialPersonal = false;
        _errorInicialPersonal = null;
      });
      _cargarMasPersonalSiHaceFalta();
    } on Object catch (error) {
      if (!mounted || version != _versionConsultaPersonal) return;

      setState(() {
        _cargandoInicialPersonal = false;
        _errorInicialPersonal = error is ApiException
            ? error.mensaje
            : 'No se pudieron cargar las cuentas.';
      });
    }
  }

  void _alDesplazarsePersonal() {
    if (_seccionActual == _SeccionCuentas.personal &&
        _scrollPersonal.hasClients &&
        _scrollPersonal.position.extentAfter < 420) {
      unawaited(_cargarMasPersonal());
    }
  }

  void _cargarMasPersonalSiHaceFalta() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _seccionActual == _SeccionCuentas.personal &&
          _scrollPersonal.hasClients &&
          _scrollPersonal.position.extentAfter < 420) {
        unawaited(_cargarMasPersonal());
      }
    });
  }

  Future<void> _cargarMasPersonal() async {
    final cursor = _cursorPersonal;
    if (!_hayMasPersonal ||
        cursor == null ||
        _cargandoInicialPersonal ||
        _cargandoMasPersonal ||
        _errorMasPersonal != null) {
      return;
    }

    final version = _versionConsultaPersonal;
    setState(() => _cargandoMasPersonal = true);
    try {
      final pagina = await widget.sesion.listarUsuarios(
        busqueda: _busquedaPersonal.text.trim(),
        rol: _filtroRol == 'todos' ? null : _filtroRol,
        cursor: cursor,
      );
      if (!mounted || version != _versionConsultaPersonal) return;

      final soloInternos = pagina.usuarios.where(_esAdminOOperario).toList();

      setState(() {
        _personal
          ..addAll(soloInternos)
          ..sort(_compararPersonal);
        _cursorPersonal = pagina.proximoCursor;
        _hayMasPersonal = _cursorPersonal != null;
        _cargandoMasPersonal = false;
        _errorMasPersonal = null;
      });
      _cargarMasPersonalSiHaceFalta();
    } on Object catch (error) {
      if (!mounted || version != _versionConsultaPersonal) return;

      setState(() {
        _cargandoMasPersonal = false;
        _errorMasPersonal = error is ApiException
            ? error.mensaje
            : 'No se pudieron cargar más cuentas.';
      });
    }
  }

  void _seleccionarRol(String valor) {
    if (_filtroRol == valor) return;
    setState(() => _filtroRol = valor);
    unawaited(_recargarPersonal());
  }

  void _limpiarFiltrosPersonal() {
    _actualizandoFiltrosPersonal = true;
    _busquedaPersonal.clear();
    _filtroRol = 'todos';
    _actualizandoFiltrosPersonal = false;
    unawaited(_recargarPersonal());
  }

  // ===========================================================================
  // LÓGICA SECCIÓN 2: VECINOS Y SANCIONES
  // ===========================================================================

  void _alCambiarBusquedaVecinos(TextEditingValue valor) {
    if (_actualizandoFiltrosVecinos) return;
    _debounceVecinos?.cancel();
    final version = _prepararNuevaConsultaVecinos();
    _debounceVecinos = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_cargarPrimeraPaginaVecinos(version)),
    );
  }

  int _prepararNuevaConsultaVecinos() {
    final version = ++_versionConsultaVecinos;
    setState(() {
      _vecinos.clear();
      _cursorVecinos = null;
      _totalVecinos = 0;
      _hayMasVecinos = true;
      _cargandoInicialVecinos = true;
      _cargandoMasVecinos = false;
      _errorInicialVecinos = null;
      _errorMasVecinos = null;
    });
    if (_scrollVecinos.hasClients) {
      _scrollVecinos.jumpTo(0);
    }
    return version;
  }

  Future<void> _recargarVecinos() async {
    _debounceVecinos?.cancel();
    await _cargarPrimeraPaginaVecinos(_prepararNuevaConsultaVecinos());
  }

  Future<void> _cargarPrimeraPaginaVecinos(int version) async {
    try {
      final busqueda = _busquedaVecinos.text.trim();

      // Pedimos en paralelo el listado de vecinos y los usuarios con sanciones
      // para asegurar que los suspendidos tengan sus datos completos.
      final resultados = await Future.wait([
        widget.sesion.listarUsuarios(
          busqueda: busqueda,
          rol: 'ciudadano',
        ),
        widget.sesion.obtenerUsuariosConSancionesOrdenados(),
      ]);

      if (!mounted || version != _versionConsultaVecinos) return;

      final pagina = resultados[0] as dynamic;
      final conSanciones = resultados[1] as List<Usuario>;

      _mapaConSanciones
        ..clear()
        ..addEntries(conSanciones.map((u) => MapEntry(u.id, u)));

      final combinados = (pagina.usuarios as List<Usuario>)
          .map(_combinarConSancion)
          .toList();

      // Aseguramos que los suspendidos que coincidan con la búsqueda estén
      // presentes arriba incluso si venían en páginas posteriores.
      final idsCargados = combinados.map((u) => u.id).toSet();
      final q = busqueda.toLowerCase();
      for (final sancionado in conSanciones) {
        if (!sancionado.estaSuspendido) continue;
        if (idsCargados.contains(sancionado.id)) continue;
        if (q.isNotEmpty) {
          final nombre =
              '${sancionado.nombre} ${sancionado.apellido}'.toLowerCase();
          if (!nombre.contains(q) &&
              !sancionado.email.toLowerCase().contains(q)) {
            continue;
          }
        }
        combinados.add(sancionado);
        idsCargados.add(sancionado.id);
      }

      combinados.sort(_compararVecinos);

      setState(() {
        _vecinos
          ..clear()
          ..addAll(combinados);
        _totalVecinos = pagina.total as int;
        _cursorVecinos = pagina.proximoCursor as String?;
        _hayMasVecinos = _cursorVecinos != null;
        _cargandoInicialVecinos = false;
        _errorInicialVecinos = null;
      });
      _cargarMasVecinosSiHaceFalta();
    } on Object catch (error) {
      if (!mounted || version != _versionConsultaVecinos) return;

      setState(() {
        _cargandoInicialVecinos = false;
        _errorInicialVecinos = error is ApiException
            ? error.mensaje
            : 'No se pudieron cargar los vecinos.';
      });
    }
  }

  void _alDesplazarseVecinos() {
    if (_seccionActual == _SeccionCuentas.vecinosSanciones &&
        _scrollVecinos.hasClients &&
        _scrollVecinos.position.extentAfter < 420) {
      unawaited(_cargarMasVecinos());
    }
  }

  void _cargarMasVecinosSiHaceFalta() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _seccionActual == _SeccionCuentas.vecinosSanciones &&
          _scrollVecinos.hasClients &&
          _scrollVecinos.position.extentAfter < 420) {
        unawaited(_cargarMasVecinos());
      }
    });
  }

  Future<void> _cargarMasVecinos() async {
    final cursor = _cursorVecinos;
    if (!_hayMasVecinos ||
        cursor == null ||
        _cargandoInicialVecinos ||
        _cargandoMasVecinos ||
        _errorMasVecinos != null) {
      return;
    }

    final version = _versionConsultaVecinos;
    setState(() => _cargandoMasVecinos = true);
    try {
      final pagina = await widget.sesion.listarUsuarios(
        busqueda: _busquedaVecinos.text.trim(),
        rol: 'ciudadano',
        cursor: cursor,
      );
      if (!mounted || version != _versionConsultaVecinos) return;

      final idsExistentes = _vecinos.map((u) => u.id).toSet();
      final nuevos = pagina.usuarios
          .where((u) => !idsExistentes.contains(u.id))
          .map(_combinarConSancion);

      setState(() {
        _vecinos
          ..addAll(nuevos)
          ..sort(_compararVecinos);
        _totalVecinos = pagina.total;
        _cursorVecinos = pagina.proximoCursor;
        _hayMasVecinos = _cursorVecinos != null;
        _cargandoMasVecinos = false;
        _errorMasVecinos = null;
      });
      _cargarMasVecinosSiHaceFalta();
    } on Object catch (error) {
      if (!mounted || version != _versionConsultaVecinos) return;

      setState(() {
        _cargandoMasVecinos = false;
        _errorMasVecinos = error is ApiException
            ? error.mensaje
            : 'No se pudieron cargar más vecinos.';
      });
    }
  }

  void _limpiarBusquedaVecinos() {
    _actualizandoFiltrosVecinos = true;
    _busquedaVecinos.clear();
    _actualizandoFiltrosVecinos = false;
    unawaited(_recargarVecinos());
  }

  Future<void> _abrirSancionesVecino(Usuario vecino) async {
    if (!vecino.estaSuspendido) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemaApp(
          child: SancionesVecinoPage(sesion: widget.sesion, vecino: vecino),
        ),
      ),
    );
    if (mounted) {
      unawaited(_recargarVecinos());
    }
  }

  @override
  void dispose() {
    _debouncePersonal?.cancel();
    _debounceVecinos?.cancel();
    _scrollPersonal
      ..removeListener(_alDesplazarsePersonal)
      ..dispose();
    _scrollVecinos
      ..removeListener(_alDesplazarseVecinos)
      ..dispose();
    _busquedaPersonal.dispose();
    _busquedaVecinos.dispose();
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                color: colors.background,
                child: _SelectorSeccionPrincipal(
                  seccionActual: _seccionActual,
                  alCambiar: (nueva) {
                    if (_seccionActual == nueva) return;
                    setState(() => _seccionActual = nueva);
                    if (nueva == _SeccionCuentas.personal) {
                      _cargarMasPersonalSiHaceFalta();
                    } else {
                      _cargarMasVecinosSiHaceFalta();
                    }
                  },
                ),
              ),
              if (_seccionActual == _SeccionCuentas.personal) ...[
                _encabezadoPersonal(colors),
                Expanded(child: _listaPersonal(context)),
              ] else ...[
                _encabezadoVecinos(colors),
                Expanded(child: _listaVecinosSanciones(context)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGETS SECCIÓN 1: PERSONAL
  // ===========================================================================

  bool get _hayFiltrosPersonal =>
      _busquedaPersonal.text.trim().isNotEmpty || _filtroRol != 'todos';

  Widget _encabezadoPersonal(FColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
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
                    controller: _busquedaPersonal,
                    onChange: _alCambiarBusquedaPersonal,
                  ),
                  hint: 'Buscar admin u operario',
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
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _cargandoInicialPersonal
                    ? 'Buscando…'
                    : '${_personal.length} ${_personal.length == 1 ? 'cuenta' : 'cuentas'}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.mutedForeground,
                ),
              ),
              if (_hayFiltrosPersonal)
                GestureDetector(
                  onTap: _limpiarFiltrosPersonal,
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
    );
  }

  Widget _listaPersonal(BuildContext context) {
    if (_cargandoInicialPersonal && _personal.isEmpty) {
      return const Center(child: FCircularProgress());
    }
    if (_errorInicialPersonal != null && _personal.isEmpty) {
      return EstadoContenido(
        tipo: EstadoContenidoTipo.error,
        titulo: 'No se pudo cargar',
        descripcion: _errorInicialPersonal!,
        icono: Icons.cloud_off_outlined,
        accion: AccionContenido(
          etiqueta: 'Reintentar',
          alActivar: () => unawaited(_recargarPersonal()),
        ),
      );
    }
    if (!_cargandoInicialPersonal && _personal.isEmpty) {
      return EstadoContenido(
        tipo: _hayFiltrosPersonal
            ? EstadoContenidoTipo.sinResultados
            : EstadoContenidoTipo.vacio,
        titulo: _hayFiltrosPersonal ? 'Sin resultados' : 'No hay personal',
        descripcion: _hayFiltrosPersonal
            ? 'Probá cambiar la búsqueda o los filtros.'
            : 'Creá cuentas para administradores u operarios desde el botón superior.',
        accion: AccionContenido(
          etiqueta: _hayFiltrosPersonal ? 'Limpiar filtros' : 'Actualizar',
          alActivar: _hayFiltrosPersonal
              ? _limpiarFiltrosPersonal
              : () => unawaited(_recargarPersonal()),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _recargarPersonal,
      child: ListView.separated(
        controller: _scrollPersonal,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _personal.length +
            (_hayMasPersonal || _errorMasPersonal != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index < _personal.length) {
            final usuario = _personal[index];
            return _PersonalCard(
              usuario: usuario,
              esUsuarioActual: usuario.id == widget.sesion.usuario?.id,
              alEditar: () => unawaited(_abrirEditorPersonal(usuario)),
            );
          }
          if (_errorMasPersonal != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FButton(
                  variant: .outline,
                  onPress: () {
                    setState(() => _errorMasPersonal = null);
                    unawaited(_cargarMasPersonal());
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

  // ===========================================================================
  // WIDGETS SECCIÓN 2: VECINOS Y SANCIONES
  // ===========================================================================

  bool get _hayBusquedaVecinos => _busquedaVecinos.text.trim().isNotEmpty;

  Widget _encabezadoVecinos(FColors colors) {
    final totalMostrado =
        _totalVecinos > _vecinos.length ? _totalVecinos : _vecinos.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FTextField(
            control: FTextFieldControl.managed(
              controller: _busquedaVecinos,
              onChange: _alCambiarBusquedaVecinos,
            ),
            hint: 'Buscar vecino por nombre o correo',
            clearable: (value) => value.text.isNotEmpty,
            prefixBuilder: (context, style, variants) =>
                FTextField.prefixIconBuilder(
                  context,
                  style,
                  variants,
                  const Icon(Icons.search, size: 18),
                ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _cargandoInicialVecinos
                    ? 'Buscando…'
                    : '$totalMostrado ${totalMostrado == 1 ? 'vecino' : 'vecinos'}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.mutedForeground,
                ),
              ),
              if (_hayBusquedaVecinos)
                GestureDetector(
                  onTap: _limpiarBusquedaVecinos,
                  child: Text(
                    'Limpiar búsqueda',
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
    );
  }

  Widget _listaVecinosSanciones(BuildContext context) {
    if (_cargandoInicialVecinos && _vecinos.isEmpty) {
      return const Center(child: FCircularProgress());
    }
    if (_errorInicialVecinos != null && _vecinos.isEmpty) {
      return EstadoContenido(
        tipo: EstadoContenidoTipo.error,
        titulo: 'No se pudieron cargar los vecinos',
        descripcion: _errorInicialVecinos!,
        icono: Icons.cloud_off_outlined,
        accion: AccionContenido(
          etiqueta: 'Reintentar',
          alActivar: () => unawaited(_recargarVecinos()),
        ),
      );
    }

    if (!_cargandoInicialVecinos && _vecinos.isEmpty) {
      return EstadoContenido(
        tipo: _hayBusquedaVecinos
            ? EstadoContenidoTipo.sinResultados
            : EstadoContenidoTipo.vacio,
        titulo: _hayBusquedaVecinos
            ? 'Sin resultados'
            : 'No hay vecinos registrados',
        descripcion: _hayBusquedaVecinos
            ? 'Probá con otro nombre o correo.'
            : null,
        accion: AccionContenido(
          etiqueta: _hayBusquedaVecinos ? 'Limpiar búsqueda' : 'Actualizar',
          alActivar: _hayBusquedaVecinos
              ? _limpiarBusquedaVecinos
              : () => unawaited(_recargarVecinos()),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _recargarVecinos,
      child: ListView.separated(
        controller: _scrollVecinos,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _vecinos.length +
            (_hayMasVecinos || _errorMasVecinos != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index < _vecinos.length) {
            final vecino = _vecinos[index];
            return _VecinoCard(
              vecino: vecino,
              alPresionar: vecino.estaSuspendido
                  ? () => unawaited(_abrirSancionesVecino(vecino))
                  : null,
            );
          }
          if (_errorMasVecinos != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FButton(
                  variant: .outline,
                  onPress: () {
                    setState(() => _errorMasVecinos = null);
                    unawaited(_cargarMasVecinos());
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

// =============================================================================
// COMPONENTES AUXILIARES
// =============================================================================

class _VecinoCard extends StatelessWidget {
  const _VecinoCard({
    required this.vecino,
    this.alPresionar,
  });

  final Usuario vecino;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final suspendido = vecino.estaSuspendido;
    final nombre = '${vecino.nombre} ${vecino.apellido}'.trim();

    final badgeColor =
        suspendido ? Colors.red.shade700 : Colors.green.shade700;
    final badgeBg = suspendido
        ? Colors.red.withValues(alpha: 0.12)
        : Colors.green.withValues(alpha: 0.12);
    final badgeBorder = suspendido
        ? Colors.red.withValues(alpha: 0.35)
        : Colors.green.withValues(alpha: 0.35);

    final contenido = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            suspendido ? Icons.block : Icons.person_outline,
            size: 20,
            color: suspendido ? colors.error : colors.mutedForeground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vecino.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.mutedForeground,
                    fontSize: 13,
                  ),
                ),
                if (suspendido && vecino.suspendidoHasta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Hasta el ${fechaCorta(vecino.suspendidoHasta!)}',
                    style: TextStyle(
                      color: colors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeBorder),
            ),
            child: Text(
              suspendido ? 'Suspendida' : 'Activa',
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (suspendido) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colors.mutedForeground,
            ),
          ],
        ],
      ),
    );

    if (alPresionar == null) return contenido;

    return FTappable(
      onPress: alPresionar,
      child: contenido,
    );
  }
}

class _SelectorSeccionPrincipal extends StatelessWidget {
  const _SelectorSeccionPrincipal({
    required this.seccionActual,
    required this.alCambiar,
  });

  final _SeccionCuentas seccionActual;
  final ValueChanged<_SeccionCuentas> alCambiar;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    Widget item({
      required _SeccionCuentas valor,
      required String etiqueta,
      required IconData icono,
    }) {
      final activo = seccionActual == valor;
      return Expanded(
        child: FTappable(
          onPress: () => alCambiar(valor),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            decoration: BoxDecoration(
              color: activo ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icono,
                  size: 16,
                  color: activo ? colors.primaryForeground : colors.foreground,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                      color:
                          activo ? colors.primaryForeground : colors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          item(
            valor: _SeccionCuentas.personal,
            etiqueta: 'Admin y Operarios',
            icono: Icons.badge_outlined,
          ),
          const SizedBox(width: 4),
          item(
            valor: _SeccionCuentas.vecinosSanciones,
            etiqueta: 'Sanciones Vecinos',
            icono: Icons.gavel_rounded,
          ),
        ],
      ),
    );
  }
}

class _PersonalCard extends StatelessWidget {
  const _PersonalCard({
    required this.usuario,
    required this.esUsuarioActual,
    required this.alEditar,
  });

  final Usuario usuario;
  final bool esUsuarioActual;
  final VoidCallback alEditar;

  @override
  Widget build(BuildContext context) {
    final nombre = '${usuario.nombre} ${usuario.apellido}'.trim();
    final colores = context.theme.colors;
    final estaActiva = usuario.activo ?? true;

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
          if (!esUsuarioActual) ...[
            const SizedBox(width: 8),
            Material(
              color: colores.secondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: alEditar,
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: colores.foreground,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpcionSelectorModal extends StatelessWidget {
  const _OpcionSelectorModal({
    required this.etiqueta,
    required this.icono,
    required this.seleccionado,
    required this.alPresionar,
  });

  final String etiqueta;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return FTappable(
      onPress: alPresionar,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: seleccionado
              ? colors.primary.withValues(alpha: 0.1)
              : colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? colors.primary : colors.border,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 18,
              color: seleccionado ? colors.primary : colors.mutedForeground,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight:
                      seleccionado ? FontWeight.w600 : FontWeight.w500,
                  color: seleccionado ? colors.primary : colors.foreground,
                ),
              ),
            ),
          ],
        ),
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
