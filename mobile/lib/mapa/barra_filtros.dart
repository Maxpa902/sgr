import 'package:flutter/material.dart';

import '../modelos/tipo_reclamo.dart';
import 'estilos.dart';

/// Barra de filtros compacta y desplegable directamente sobre el mapa.
class BarraFiltros extends StatefulWidget {
  const BarraFiltros({
    super.key,
    required this.estados,
    required this.tipos,
    required this.tiposElegidos,
    required this.desplegado,
    required this.alAlternarDesplegado,
    required this.alCambiarEstado,
    required this.alCambiarTipo,
    required this.alSeleccionarTodosLosEstados,
    required this.alSeleccionarTodasLasCategorias,
  });

  final Set<String> estados;
  final List<TipoReclamo> tipos;
  final Set<int>? tiposElegidos;
  final bool desplegado;
  final VoidCallback alAlternarDesplegado;
  final ValueChanged<String> alCambiarEstado;
  final ValueChanged<int> alCambiarTipo;
  final VoidCallback alSeleccionarTodosLosEstados;
  final VoidCallback alSeleccionarTodasLasCategorias;

  @override
  State<BarraFiltros> createState() => _BarraFiltrosState();
}

class _BarraFiltrosState extends State<BarraFiltros> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final todosEstadosActivos =
        widget.estados.length == estadosDelMapa.length;
    final todasCategoriasActivas = widget.tiposElegidos == null ||
        widget.tiposElegidos!.length == widget.tipos.length;

    final String textoBoton = (todosEstadosActivos && todasCategoriasActivas)
        ? 'Filtros (Todos)'
        : 'Filtros (${widget.estados.length + (widget.tiposElegidos?.length ?? widget.tipos.length)})';

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 16, right: 16),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BOTÓN PRINCIPAL COMPACTO
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              color: colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: widget.alAlternarDesplegado,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.desplegado ? Icons.tune : Icons.filter_list,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        textoBoton,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: widget.desplegado ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // PANEL DESPLEGABLE FLOTANTE SOBRE EL MAPA
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: widget.desplegado
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  color: colorScheme.surface.withOpacity(0.96),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                    child: Scrollbar(
                      controller: _scrollController, 
                      thumbVisibility: true,
                      thickness: 5,
                      radius: const Radius.circular(8),
                      child: SingleChildScrollView(
                        controller: _scrollController, 
                        padding: const EdgeInsets.only(right: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Estado',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                FilterChip(
                                  selected: todosEstadosActivos,
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      widget.alSeleccionarTodosLosEstados(),
                                  label: const Text('Todos'),
                                  labelStyle: TextStyle(
                                    color: todosEstadosActivos
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: todosEstadosActivos
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  selectedColor: colorScheme.primary,
                                  backgroundColor: Colors.grey.shade100,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(
                                    color: todosEstadosActivos
                                        ? colorScheme.primary
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                for (final estado in estadosDelMapa)
                                  _ChipEstado(
                                    estado: estado,
                                    seleccionado:
                                        widget.estados.contains(estado),
                                    onSelected: () =>
                                        widget.alCambiarEstado(estado),
                                  ),
                              ],
                            ),
                            if (widget.tipos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text(
                                    'Categoría',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.unfold_more,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  FilterChip(
                                    selected: todasCategoriasActivas,
                                    showCheckmark: false,
                                    onSelected: (_) =>
                                        widget.alSeleccionarTodasLasCategorias(),
                                    label: const Text('Todas'),
                                    labelStyle: TextStyle(
                                      color: todasCategoriasActivas
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: todasCategoriasActivas
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    selectedColor: colorScheme.primary,
                                    backgroundColor: Colors.grey.shade100,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: BorderSide(
                                      color: todasCategoriasActivas
                                          ? colorScheme.primary
                                          : Colors.grey.shade300,
                                      width: 1,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  for (final tipo in widget.tipos)
                                    _ChipTipo(
                                      tipo: tipo,
                                      seleccionado: widget.tiposElegidos
                                              ?.contains(tipo.id) ??
                                          true,
                                      onSelected: () =>
                                          widget.alCambiarTipo(tipo.id),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({
    required this.estado,
    required this.seleccionado,
    required this.onSelected,
  });

  final String estado;
  final bool seleccionado;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = colorDelEstado(estado);

    return FilterChip(
      selected: seleccionado,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      avatar: CircleAvatar(
        backgroundColor: seleccionado ? Colors.white : color,
        radius: 5,
      ),
      label: Text(nombreDelFiltro(estado)),
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : Colors.black87,
        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      selectedColor: color,
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      side: BorderSide(
        color: seleccionado ? color : Colors.grey.shade300,
        width: 1,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ChipTipo extends StatelessWidget {
  const _ChipTipo({
    required this.tipo,
    required this.seleccionado,
    required this.onSelected,
  });

  final TipoReclamo tipo;
  final bool seleccionado;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      selected: seleccionado,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      avatar: Icon(
        iconoDeCategoria(tipo.icono),
        size: 14,
        color: seleccionado ? colorScheme.onPrimary : colorScheme.primary,
      ),
      label: Text(tipo.nombre),
      labelStyle: TextStyle(
        color: seleccionado ? colorScheme.onPrimary : colorScheme.onSurface,
        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      side: BorderSide(
        color: seleccionado ? colorScheme.primary : Colors.grey.shade300,
        width: 1,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}