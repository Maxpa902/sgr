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
  final Set<int> _cambiandoActivo = <int>{};
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
      return c.nombre.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  Future<void> _mostrarFormularioCategoria({TipoReclamo? categoriaExistente}) async {
    final nombreCtrl = TextEditingController(text: categoriaExistente?.nombre ?? '');
    final descCtrl = TextEditingController(text: categoriaExistente?.descripcion ?? '');
    String? iconoSeleccionado =
        _etiquetasIcono.containsKey(categoriaExistente?.icono)
            ? categoriaExistente?.icono
            : null;
    bool activo = categoriaExistente?.activo ?? true;
    bool guardando = false;

    final guardado = await showFDialog<bool>(
      context: context,
      builder: (dialogContext, _, animation) => StatefulBuilder(
        builder: (modalContext, setStateModal) => FDialog(
          animation: animation,
          builder: (innerContext, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoriaExistente == null ? 'Nueva Categoría' : 'Editar Categoría',
                  style: innerContext.theme.typography.body.lg,
                ),
                const SizedBox(height: 16),
                FTextField(
                  control: FTextFieldControl.managed(controller: nombreCtrl),
                  label: const Text('Nombre'),
                ),
                const SizedBox(height: 12),
                FTextField(
                  control: FTextFieldControl.managed(controller: descCtrl),
                  label: const Text('Descripción'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ícono',
                  style: innerContext.theme.typography.body.sm,
                ),
                const SizedBox(height: 8),
                Material(
                  type: MaterialType.transparency,
                  child: DropdownButtonFormField<String?>(
                    value: iconoSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        : (val) => setStateModal(() => iconoSeleccionado = val),
                  ),
                ),
                const SizedBox(height: 14),
                FCheckbox(
                  value: activo,
                  onChange: guardando
                      ? null
                      : (v) => setStateModal(() => activo = v),
                  label: const Text('Categoría activa'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FButton(
                      variant: .outline,
                      onPress: guardando
                          ? null
                          : () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FButton(
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

                              setStateModal(() => guardando = true);
                              try {
                                if (categoriaExistente == null) {
                                  await widget.sesion.crearCategoria(
                                    nombre: nombreLimpio,
                                    descripcion: descLimpia.isEmpty ? null : descLimpia,
                                    icono: iconoSeleccionado,
                                  );
                                } else {
                                  await widget.sesion.actualizarCategoria(
                                    categoriaExistente.id,
                                    nombre: nombreLimpio,
                                    descripcion: descLimpia.isEmpty ? null : descLimpia,
                                    icono: iconoSeleccionado,
                                    activo: activo,
                                  );
                                }
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop(true);
                                }
                              } on ApiException catch (e) {
                                if (modalContext.mounted) {
                                  setStateModal(() => guardando = false);
                                }
                                _mostrarMensaje(e.mensaje);
                              } catch (e) {
                                if (modalContext.mounted) {
                                  setStateModal(() => guardando = false);
                                }
                                _mostrarMensaje('Error al guardar: $e');
                              }
                            },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _alternarActivo(TipoReclamo cat, bool nuevoValor) async {
    if (_cambiandoActivo.contains(cat.id)) return;

    setState(() => _cambiandoActivo.add(cat.id));
    try {
      await widget.sesion.toggleActivoCategoria(cat.id, nuevoValor);
      if (mounted) {
        _mostrarMensaje(
          nuevoValor ? 'Categoría activada.' : 'Categoría desactivada.',
          tipo: TipoNotificacion.exito,
          id: 'categoria-estado',
        );
        _cargar();
      }
    } on ApiException catch (e) {
      _mostrarMensaje(e.mensaje, tipo: TipoNotificacion.error);
    } catch (e) {
      _mostrarMensaje(
        'No se pudo actualizar la categoría: $e',
        tipo: TipoNotificacion.error,
      );
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
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                      decoration: BoxDecoration(
                        color: seleccionada ? colors.background : Colors.transparent,
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
                          fontWeight: seleccionada ? FontWeight.w600 : FontWeight.w400,
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

    return LayoutPagina(
      titulo: 'Categorías',
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
                            onChange: (valor) {
                              setState(() => _textoBusqueda = valor.text);
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
                          onTap: () => _mostrarFormularioCategoria(),
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
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<TipoReclamo>>(
                future: _futuroCategorias,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: FCircularProgress());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error al cargar categorías: ${snapshot.error}'),
                      ),
                    );
                  }

                  final todasCategorias = snapshot.requireData;
                  final categoriasFiltradas = _aplicarFiltros(todasCategorias);

                  if (categoriasFiltradas.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No hay categorías que coincidan con la búsqueda.'),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: categoriasFiltradas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cat = categoriasFiltradas[index];
                      return FTile(
                        prefix: Icon(_iconoParaClave(cat.icono), size: 22),
                        title: Text(cat.nombre),
                        subtitle: Text(cat.descripcion ?? 'Sin descripción'),
                        suffix: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              type: MaterialType.transparency,
                              child: Switch(
                                value: cat.activo,
                                activeColor: Colors.green.shade600,
                                activeTrackColor: Colors.green.shade200,
                                inactiveThumbColor: Colors.grey.shade600,
                                inactiveTrackColor: Colors.grey.shade300,
                                onChanged: _cambiandoActivo.contains(cat.id)
                                    ? null
                                    : (val) => _alternarActivo(cat, val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.amber.shade400,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _mostrarFormularioCategoria(
                                  categoriaExistente: cat,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.edit,
                                    size: 17,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
