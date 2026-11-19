import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../formato.dart';
import '../modelos/comentario.dart';
import '../sesion/sesion.dart';
import '../tema/colores.dart';

/// Comentarios de un reclamo: la lista, el campo para escribir uno nuevo y, en
/// los propios, editar y borrar.
///
/// Las reglas (límite de 3, reclamo finalizado, suspensión) las decide el server;
/// esta sección solo muestra lo que el server permite y por qué no permite lo demás.
class ComentariosReclamo extends StatefulWidget {
  const ComentariosReclamo({
    super.key,
    required this.sesion,
    required this.reclamoId,
  });

  final Sesion sesion;
  final int reclamoId;

  @override
  State<ComentariosReclamo> createState() => _ComentariosReclamoState();
}

class _ComentariosReclamoState extends State<ComentariosReclamo> {
  final _nuevo = TextEditingController();
  ComentariosDeReclamo? _datos;
  bool _cargando = true;
  bool _falloLaCarga = false;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nuevo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _falloLaCarga = false;
    });
    try {
      final datos = await widget.sesion.api.listarComentarios(widget.reclamoId);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _falloLaCarga = true;
      });
    }
  }

  /// Hace el pedido al server y, si sale bien, recarga la lista. Devuelve si salió bien.
  Future<bool> _ejecutar(Future<void> Function() pedido) async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await pedido();
      if (!mounted) return false;
      setState(() {
        _enviando = false;
      });
      await _cargar();
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = error.mensaje;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = 'No se pudo completar la acción. Probá de nuevo.';
        });
      }
    }
    return false;
  }

  Future<void> _publicar() async {
    final texto = _nuevo.text.trim();
    if (texto.isEmpty) {
      setState(() {
        _error = 'Escribí el comentario.';
      });
      return;
    }
    final publicado = await _ejecutar(
      () => widget.sesion.api.crearComentario(widget.reclamoId, texto),
    );
    if (publicado) _nuevo.clear();
  }

  Future<void> _editar(Comentario comentario) async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoEditar(textoInicial: comentario.contenido),
    );
    if (texto == null || texto == comentario.contenido) return;
    await _ejecutar(
      () => widget.sesion.api.editarComentario(comentario.id, texto),
    );
  }

  Future<void> _borrar(Comentario comentario) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar comentario?'),
        content: const Text('No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await _ejecutar(() => widget.sesion.api.borrarComentario(comentario.id));
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final datos = _datos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Comentarios', style: textos.titleMedium),
        const SizedBox(height: 12),
        if (datos == null && _cargando)
          const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (datos == null && _falloLaCarga)
          Row(
            children: [
              Expanded(
                child: Text(
                  'No se pudieron cargar los comentarios.',
                  style: textos.bodyMedium,
                ),
              ),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          )
        else if (datos != null) ...[
          if (datos.comentarios.isEmpty)
            Text('Todavía no hay comentarios.', style: textos.bodyMedium)
          else
            for (final comentario in datos.comentarios)
              _TarjetaComentario(
                comentario: comentario,
                puedeModificar:
                    comentario.esMio &&
                    datos.puedeModificarPropios &&
                    !_enviando,
                alEditar: () => _editar(comentario),
                alBorrar: () => _borrar(comentario),
              ),
          const SizedBox(height: 8),
          if (datos.puedeComentar) ...[
            TextField(
              controller: _nuevo,
              enabled: !_enviando,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribí un comentario',
                helperText: _quedan(datos.disponibles),
                border: const OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _enviando ? null : _publicar,
                child: Text(_enviando ? 'Enviando…' : 'Comentar'),
              ),
            ),
          ] else
            Text(
              datos.motivoBloqueo!,
              style: textos.bodyMedium?.copyWith(
                color: ColoresApp.textoSecundario,
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: ColoresApp.error)),
          ],
        ],
      ],
    );
  }

  static String _quedan(int disponibles) => disponibles == 1
      ? 'Te queda 1 comentario en este reclamo'
      : 'Te quedan $disponibles comentarios en este reclamo';
}

/// Un comentario con su autor, cuándo se escribió y, si es propio, editar y borrar.
class _TarjetaComentario extends StatelessWidget {
  const _TarjetaComentario({
    required this.comentario,
    required this.puedeModificar,
    required this.alEditar,
    required this.alBorrar,
  });

  final Comentario comentario;
  final bool puedeModificar;
  final VoidCallback alEditar;
  final VoidCallback alBorrar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cuando = [
      haceCuanto(comentario.creadoEn),
      if (comentario.editado) 'editado',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
      decoration: BoxDecoration(
        color: ColoresApp.fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: comentario.autor,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' · $cuando',
                        style: const TextStyle(
                          color: ColoresApp.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                  style: textos.bodySmall,
                ),
              ),
              if (puedeModificar) ...[
                IconButton(
                  tooltip: 'Editar comentario',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: alEditar,
                ),
                IconButton(
                  tooltip: 'Borrar comentario',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: alBorrar,
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(comentario.contenido, style: textos.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Pide el texto nuevo del comentario. Devuelve el texto, o `null` si se cancela.
class _DialogoEditar extends StatefulWidget {
  const _DialogoEditar({required this.textoInicial});

  final String textoInicial;

  @override
  State<_DialogoEditar> createState() => _DialogoEditarState();
}

class _DialogoEditarState extends State<_DialogoEditar> {
  late final _texto = TextEditingController(text: widget.textoInicial);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _guardar() {
    final texto = _texto.text.trim();
    if (texto.isNotEmpty) Navigator.pop(context, texto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar comentario'),
      content: TextField(
        controller: _texto,
        autofocus: true,
        minLines: 1,
        maxLines: 5,
        maxLength: 1000,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
