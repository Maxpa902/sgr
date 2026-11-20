import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:mobile/mapa/estilos.dart';

import '../api/api_exception.dart';
import '../modelos/tipo_reclamo.dart';
import '../sesion/sesion.dart';
import '../widgets/componentes_ui.dart';
import '../widgets/ui/notificaciones.dart';

enum _FiltroEstadoCategoria { todas, activas, desactivadas }

class AdminCategoriasPage extends StatefulWidget {
  const AdminCategoriasPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<AdminCategoriasPage> createState() => _AdminCategoriasPageState();
}

class _AdminCategoriasPageState extends State<AdminCategoriasPage> {
  late Future<List<TipoReclamo>> _futuroCategorias;
  final _busqueda = TextEditingController();
  String _textoBusqueda = '';
  _FiltroEstadoCategoria _filtroEstado = _FiltroEstadoCategoria.todas;

  static const Map<String, String> _etiquetasIcono = {
    'electricidad': 'Electricidad',
    'alumbrado': 'Alumbrado',
    'agua': 'Agua',
    'cloacas': 'Cloacas',
    'telefonia': 'Telefonía',
    'baches': 'Baches y calles',
    'veredas': 'Veredas',
    'arbolado': 'Arbolado y poda',
    'residuos': 'Residuos y limpieza',
    'transito': 'Tránsito y señales',
    'pluviales': 'Desagües pluviales',
    'seguridad': 'Seguridad vial',
    'espacios_verdes': 'Plazas y parques',
    'mobiliario': 'Mobiliario urbano',
  };

  List<MapEntry<String, String>> get _opcionesOrdenadas {
    final entradas = _etiquetasIcono.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entradas;
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _cargar() {
    setState(() {
      _futuroCategorias = widget.sesion.tiposDeReclamoAdmin();
    });
  }

  Future<void> _recargar() async {
    _cargar();
    await _futuroCategorias;
  }

  void _mostrarMensaje(
    String mensaje, {
    TipoNotificacion tipo = TipoNotificacion.error,
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

  IconData _iconoParaClave(String? clave) {
    if (clave == null || clave.trim().isEmpty) return Icons.category;
    return iconoDeCategoria(clave);
  }

  List<TipoReclamo> _aplicarFiltros(List<TipoReclamo> categorias) {
    final q = _textoBusqueda.trim().toLowerCase();
    return categorias.where((c) {
      final coincideEstado = switch (_filtroEstado) {
        _FiltroEstadoCategoria.todas => true,
        _FiltroEstadoCategoria.activas => c.activo,
        _FiltroEstadoCategoria.desactivadas => !c.activo,
      };
      if (!coincideEstado) return false;
      if (q.isEmpty) return true;
      return c.nombre.toLowerCase().contains(q) ||
          (c.descripcion?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  bool get _hayFiltros =>
      _textoBusqueda.trim().isNotEmpty ||
      _filtroEstado != _FiltroEstadoCategoria.todas;

  void _limpiarFiltros() {
    setState(() {
      _busqueda.clear();
      _textoBusqueda = '';
      _filtroEstado = _FiltroEstadoCategoria.todas;
    });
  }

  Future<void> _abrirFormularioCategoria({TipoReclamo? categoriaExistente}) async {
    final colors = context.theme.colors;
    final nombreCtrl =
        TextEditingController(text: categoriaExistente?.nombre ?? '');
    final descCtrl =
        TextEditingController(text: categoriaExistente?.descripcion ?? '');
    String? iconoSeleccionado =
        _etiquetasIcono.containsKey(categoriaExistente?.icono)
            ? categoriaExistente?.icono
            : null;
    bool activo = categoriaExistente?.activo ?? true;
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
            final esEdicion = categoriaExistente != null;
            return SafeArea(
              child: SingleChildScrollView(
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
                                esEdicion
                                    ? 'Editar categoría'
                                    : 'Nueva categoría',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.foreground,
                                ),
                              ),
                              if (esEdicion) ...[
                                const SizedBox(height: 2),
                                Text(
                                  categoriaExistente.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.mutedForeground,
                                  ),
                                ),
                              ],
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
                    const SizedBox(height: 16),
                    FTextField(
                      control: FTextFieldControl.managed(controller: nombreCtrl),
                      label: const Text('Nombre'),
                      hint: 'Ej. Alumbrado público',
                    ),
                    const SizedBox(height: 12),
                    FTextField(
                      control: FTextFieldControl.managed(controller: descCtrl),
                      label: const Text('Descripción'),
                      hint: 'Opcional',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Ícono',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      type: MaterialType.transparency,
                      child: DropdownButtonFormField<String?>(
                        value: iconoSeleccionado,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.category, size: 18),
                                SizedBox(width: 10),
                                Text('Genérico (por defecto)'),
                              ],
                            ),
                          ),
                          for (final entry in _opcionesOrdenadas)
                            DropdownMenuItem<String?>(
                              value: entry.key,
                              child: Row(
                                children: [
                                  Icon(iconoDeCategoria(entry.key), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        onChanged: guardando
                            ? null
                            : (val) =>
                                setModalState(() => iconoSeleccionado = val),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                  'Categoría activa',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activo
                                      ? 'Disponible al crear nuevos reclamos'
                                      : 'Oculta para nuevos reclamos',
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
                              value: activo,
                              activeColor: Colors.green.shade600,
                              activeTrackColor: Colors.green.shade200,
                              onChanged: guardando
                                  ? null
                                  : (val) => setModalState(() => activo = val),
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
                                    final nombreLimpio = nombreCtrl.text.trim();
                                    final descLimpia = descCtrl.text.trim();

                                    if (nombreLimpio.isEmpty) {
                                      _mostrarMensaje(
                                        'Ingresá un nombre para la categoría.',
                                        tipo: TipoNotificacion.advertencia,
                                        id: 'validacion-categoria',
                                      );
                                      return;
                                    }

                                    setModalState(() => guardando = true);
                                    try {
                                      if (categoriaExistente == null) {
                                        await widget.sesion.crearCategoria(
                                          nombre: nombreLimpio,
                                          descripcion: descLimpia.isEmpty
                                              ? null
                                              : descLimpia,
                                          icono: iconoSeleccionado,
                                        );
                                        if (!activo) {
                                          // Si se creó desactivada y el endpoint
                                          // crea activa por defecto, actualizamos.
                                          final lista = await widget.sesion
                                              .tiposDeReclamoAdmin();
                                          final creada = lista
                                              .where(
                                                (c) =>
                                                    c.nombre.toLowerCase() ==
                                                    nombreLimpio.toLowerCase(),
                                              )
                                              .firstOrNull;
                                          if (creada != null) {
                                            await widget.sesion
                                                .toggleActivoCategoria(
                                              creada.id,
                                              false,
                                            );
                                          }
                                        }
                                      } else {
                                        await widget.sesion.actualizarCategoria(
                                          categoriaExistente.id,
                                          nombre: nombreLimpio,
                                          descripcion: descLimpia.isEmpty
                                              ? null
                                              : descLimpia,
                                          icono: iconoSeleccionado,
                                          activo: activo,
                                        );
                                      }
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop(true);
                                      }
                                    } on ApiException catch (e) {
                                      if (ctx.mounted) {
                                        setModalState(() => guardando = false);
                                      }
                                      _mostrarMensaje(e.mensaje);
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setModalState(() => guardando = false);
                                      }
                                      _mostrarMensaje('Error al guardar: $e');
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
        categoriaExistente == null
            ? 'Categoría creada correctamente.'
            : 'Categoría actualizada correctamente.',
        tipo: TipoNotificacion.exito,
        id: 'categoria-guardada',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargar();
      });
    }
  }

  Widget _construirFiltros(BuildContext context) {
    final colors = context.theme.colors;
    const opciones = [
      (_FiltroEstadoCategoria.todas, 'Todas'),
      (_FiltroEstadoCategoria.activas, 'Activas'),
      (_FiltroEstadoCategoria.desactivadas, 'Desactivadas'),
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
                  final estado = opciones[i].$1;
                  final texto = opciones[i].$2;
                  final seleccionada = _filtroEstado == estado;

                  return FTappable(
                    onPress: () => setState(() => _filtroEstado = estado),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Scaffold(
      body: LayoutPagina(
        titulo: 'Categorías',
        alVolver: () => Navigator.of(context).pop(),
        superficie: SuperficiePagina.bordeABorde,
        contenido: SafeArea(
          child: FutureBuilder<List<TipoReclamo>>(
            future: _futuroCategorias,
            builder: (context, snapshot) {
              final cargando =
                  snapshot.connectionState != ConnectionState.done;
              final todas = snapshot.data ?? const <TipoReclamo>[];
              final filtradas = _aplicarFiltros(todas);

              return Column(
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
                                  onChange: (valor) {
                                    setState(
                                      () => _textoBusqueda = valor.text,
                                    );
                                  },
                                ),
                                hint: 'Buscar por nombre',
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
                                onTap: () => _abrirFormularioCategoria(),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.add,
                                    size: 20,
                                    color: colors.primaryForeground,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _construirFiltros(context),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cargando
                                  ? 'Cargando…'
                                  : '${filtradas.length} ${filtradas.length == 1 ? 'categoría' : 'categorías'}',
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
                  Expanded(
                    child: _contenidoLista(
                      context,
                      snapshot: snapshot,
                      filtradas: filtradas,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _contenidoLista(
    BuildContext context, {
    required AsyncSnapshot<List<TipoReclamo>> snapshot,
    required List<TipoReclamo> filtradas,
  }) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: FCircularProgress());
    }
    if (snapshot.hasError) {
      final error = snapshot.error;
      return EstadoContenido(
        tipo: EstadoContenidoTipo.error,
        titulo: 'No se pudieron cargar las categorías',
        descripcion: error is ApiException ? error.mensaje : '$error',
        icono: Icons.cloud_off_outlined,
        accion: AccionContenido(
          etiqueta: 'Reintentar',
          alActivar: _cargar,
        ),
      );
    }
    if (filtradas.isEmpty) {
      return EstadoContenido(
        tipo: _hayFiltros
            ? EstadoContenidoTipo.sinResultados
            : EstadoContenidoTipo.vacio,
        titulo: _hayFiltros ? 'Sin resultados' : 'No hay categorías',
        descripcion: _hayFiltros
            ? 'Probá cambiar la búsqueda o los filtros.'
            : 'Creá una categoría desde el botón superior.',
        accion: AccionContenido(
          etiqueta: _hayFiltros ? 'Limpiar filtros' : 'Actualizar',
          alActivar: _hayFiltros ? _limpiarFiltros : _cargar,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: filtradas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final cat = filtradas[index];
          return _CategoriaCard(
            categoria: cat,
            icono: _iconoParaClave(cat.icono),
            alEditar: () => unawaited(
              _abrirFormularioCategoria(categoriaExistente: cat),
            ),
          );
        },
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  const _CategoriaCard({
    required this.categoria,
    required this.icono,
    required this.alEditar,
  });

  final TipoReclamo categoria;
  final IconData icono;
  final VoidCallback alEditar;

  @override
  Widget build(BuildContext context) {
    final colores = context.theme.colors;
    final estaActiva = categoria.activo;
    final descripcion = categoria.descripcion?.trim();

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
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: colores.secondary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icono,
              size: 20,
              color: colores.foreground,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoria.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  (descripcion != null && descripcion.isNotEmpty)
                      ? descripcion
                      : 'Sin descripción',
                  maxLines: 2,
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
      ),
    );
  }
}
