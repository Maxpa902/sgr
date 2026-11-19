import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../modelos/usuario.dart';
import '../sesion/sesion.dart';

/// Selector de empleados activos para asignar o reasignar un reclamo.
class SelectorResponsableSheet extends StatefulWidget {
  const SelectorResponsableSheet({
    super.key,
    required this.sesion,
    required this.reclamoId,
  });

  final Sesion sesion;
  final int reclamoId;

  @override
  State<SelectorResponsableSheet> createState() =>
      _SelectorResponsableSheetState();
}

class _SelectorResponsableSheetState extends State<SelectorResponsableSheet> {
  final _busqueda = TextEditingController();
  final _scroll = ScrollController();
  final List<Usuario> _empleados = [];
  Timer? _debounce;
  String? _cursor;
  String? _error;
  bool _cargando = false;
  bool _hayMas = true;
  bool _guardando = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazarse);
    _buscar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _alDesplazarse() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 200) _cargarMas();
  }

  void _buscar() {
    final version = ++_version;
    setState(() {
      _empleados.clear();
      _cursor = null;
      _hayMas = true;
      _cargando = false;
      _error = null;
    });
    _cargarMas(version: version);
  }

  Future<void> _cargarMas({int? version}) async {
    if (_cargando || !_hayMas || _guardando) return;
    final pedido = version ?? _version;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await widget.sesion.listarUsuarios(
        busqueda: _busqueda.text.trim(),
        rol: 'empleado',
        estado: 'activa',
        cursor: _cursor,
      );
      if (!mounted || pedido != _version) return;
      setState(() {
        _empleados.addAll(pagina.usuarios);
        _cursor = pagina.proximoCursor;
        _hayMas = _cursor != null;
      });
    } on ApiException catch (error) {
      if (mounted && pedido == _version) setState(() => _error = error.mensaje);
    } catch (_) {
      if (mounted && pedido == _version) {
        setState(() => _error = 'No se pudieron cargar los empleados.');
      }
    } finally {
      if (mounted && pedido == _version) setState(() => _cargando = false);
    }
  }

  Future<void> _asignar(Usuario usuario) async {
    if (_guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.sesion.api.asignarReclamo(widget.reclamoId, usuario.id);
      if (mounted) {
        setState(() => _guardando = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo asignar el reclamo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.sesion.usuario;
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final altura = math.min(
      size.height * 0.7,
      math.max(
        0.0,
        size.height - insets.bottom - padding.top - padding.bottom - 24,
      ),
    );
    return PopScope(
      canPop: !_guardando,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SizedBox(
            height: altura,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Asignar responsable',
                          style: context.theme.typography.body.lg,
                        ),
                      ),
                      FButton.icon(
                        variant: .ghost,
                        onPress: _guardando
                            ? null
                            : () => Navigator.pop(context),
                        semanticsLabel: 'Cerrar',
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FTextField(
                    control: FTextFieldControl.managed(
                      controller: _busqueda,
                      onChange: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 350),
                          _buscar,
                        );
                      },
                    ),
                    enabled: !_guardando,
                    hint: 'Buscar empleado',
                    prefixBuilder: (context, style, variants) =>
                        FTextField.prefixIconBuilder(
                          context,
                          style,
                          variants,
                          const Icon(Icons.search),
                        ),
                  ),
                ),
                if (_guardando) const Center(child: FCircularProgress()),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.theme.colors.error),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    children: [
                      if (admin != null &&
                          admin.esAdmin &&
                          _busqueda.text.trim().isEmpty)
                        FTile(
                          prefix: const Icon(Icons.person_outline),
                          title: const Text('Asignarme este reclamo'),
                          subtitle: Text('${admin.nombre} ${admin.apellido}'),
                          enabled: !_guardando,
                          onPress: _guardando ? null : () => _asignar(admin),
                        ),
                      for (final usuario in _empleados)
                        FTile(
                          prefix: const Icon(Icons.person_outline),
                          title: Text('${usuario.nombre} ${usuario.apellido}'),
                          subtitle: Text(usuario.email),
                          enabled: !_guardando,
                          onPress: _guardando ? null : () => _asignar(usuario),
                        ),
                      if (_cargando)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: FCircularProgress()),
                        ),
                      if (!_cargando && _error != null && _hayMas)
                        Center(
                          child: FButton(
                            variant: .outline,
                            mainAxisSize: MainAxisSize.min,
                            onPress: _cargarMas,
                            child: const Text('Reintentar'),
                          ),
                        ),
                      if (!_cargando && _error == null && _empleados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No se encontraron empleados activos.'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RechazarReclamoSheet extends StatefulWidget {
  const RechazarReclamoSheet({
    super.key,
    required this.sesion,
    required this.reclamoId,
    this.soloFalso = false,
  });

  final Sesion sesion;
  final int reclamoId;
  final bool soloFalso;

  @override
  State<RechazarReclamoSheet> createState() => _RechazarReclamoSheetState();
}

class _RechazarReclamoSheetState extends State<RechazarReclamoSheet> {
  final _motivo = TextEditingController();
  bool _esFalso = false;

  @override
  void initState() {
    super.initState();
    _esFalso = widget.soloFalso;
  }
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _rechazar() async {
    if (_guardando) return;
    final motivo = _motivo.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'Escribí un motivo para rechazar el reclamo.');
      return;
    }
    final confirmado = await showFDialog<bool>(
      context: context,
      builder: (context, _, animation) => FDialog(
        animation: animation,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Rechazar reclamo?',
                style: context.theme.typography.body.lg,
              ),
              const SizedBox(height: 12),
              Text(
                _esFalso
                    ? 'El rechazo es definitivo y el vecino quedará suspendido durante 30 días.'
                    : 'El rechazo es definitivo y el motivo será visible públicamente.',
              ),
              const SizedBox(height: 20),
              FButton(
                variant: .destructive,
                onPress: () => Navigator.pop(context, true),
                child: const Text('Rechazar'),
              ),
              const SizedBox(height: 8),
              FButton(
                variant: .outline,
                onPress: () => Navigator.pop(context, false),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.sesion.api.rechazarReclamo(
        widget.reclamoId,
        observacion: motivo,
        esFalso: _esFalso,
      );
      if (mounted) {
        setState(() => _guardando = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo rechazar el reclamo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rechazar reclamo',
                      style: context.theme.typography.body.lg,
                    ),
                  ),
                  FButton.icon(
                    variant: .ghost,
                    onPress: _guardando ? null : () => Navigator.pop(context),
                    semanticsLabel: 'Cerrar',
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('El motivo será público y el rechazo es definitivo.'),
              const SizedBox(height: 16),
              FTextField.multiline(
                control: FTextFieldControl.managed(controller: _motivo),
                enabled: !_guardando,
                minLines: 3,
                maxLines: 5,
                maxLength: 5000,
                label: const Text('Motivo del rechazo'),
              ),
              const SizedBox(height: 16),
              if (widget.soloFalso)
                const Text('El rechazo por falso suspende al vecino durante 30 días.')
              else
              FCheckbox(
                value: _esFalso,
                enabled: !_guardando,
                onChange: _guardando
                    ? null
                    : (valor) => setState(() => _esFalso = valor),
                label: const Text('El reclamo es falso'),
                description: const Text(
                  'El vecino queda suspendido durante 30 días.',
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: context.theme.colors.error),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FButton(
                  variant: .destructive,
                  onPress: _guardando ? null : _rechazar,
                  child: Text(_guardando ? 'Rechazando…' : 'Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
