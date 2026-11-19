import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../sesion/sesion.dart';
import '../validaciones.dart';
import '../widgets/componentes_ui.dart';

class EditarPerfilPage extends StatefulWidget {
  const EditarPerfilPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _apellido;
  late final TextEditingController _email;
  late final TextEditingController _telefono;
  final _passwordActual = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmacion = TextEditingController();

  bool _enviando = false;
  String? _error;
  Map<String, String> _erroresDelServer = {};

  @override
  void initState() {
    super.initState();
    final usuario = widget.sesion.usuario!;
    _nombre = TextEditingController(text: usuario.nombre);
    _apellido = TextEditingController(text: usuario.apellido);
    _email = TextEditingController(text: usuario.email);
    _telefono = TextEditingController(text: usuario.telefono ?? '');
  }

  @override
  void dispose() {
    for (final campo in [
      _nombre,
      _apellido,
      _email,
      _telefono,
      _passwordActual,
      _password,
      _passwordConfirmacion,
    ]) {
      campo.dispose();
    }
    super.dispose();
  }

  bool get _quiereCambiarPassword =>
      _passwordActual.text.isNotEmpty ||
      _password.text.isNotEmpty ||
      _passwordConfirmacion.text.isNotEmpty;

  Future<void> _guardarCambios() async {
    setState(() {
      _error = null;
      _erroresDelServer = {};
    });
    if (!_formulario.currentState!.validate()) {
      return;
    }

    setState(() => _enviando = true);
    try {
      await widget.sesion.actualizarPerfil(
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        email: _email.text.trim(),
        telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
        passwordActual: _quiereCambiarPassword ? _passwordActual.text : null,
        password: _quiereCambiarPassword ? _password.text : null,
        passwordConfirmacion: _quiereCambiarPassword
            ? _passwordConfirmacion.text
            : null,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.mensaje;
          _erroresDelServer = error.errores;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  void _limpiarErrorDelServer(String campo) {
    if (_erroresDelServer.containsKey(campo)) {
      setState(() => _erroresDelServer = {..._erroresDelServer}..remove(campo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutPagina(
      titulo: 'Editar perfil',
      alVolver: () {
        if (!_enviando) Navigator.of(context).pop(false);
      },
      superficie: SuperficiePagina.bordeABorde,
      contenido: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formulario,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Datos personales',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _campo(
                        campo: 'nombre',
                        etiqueta: 'Nombre',
                        controlador: _nombre,
                        icono: Icons.person_outline,
                        autofill: AutofillHints.givenName,
                        validador: obligatorio('Ingresá tu nombre.'),
                      ),
                      _campo(
                        campo: 'apellido',
                        etiqueta: 'Apellido',
                        controlador: _apellido,
                        icono: Icons.person_outline,
                        autofill: AutofillHints.familyName,
                        validador: obligatorio('Ingresá tu apellido.'),
                      ),
                      _campo(
                        campo: 'email',
                        etiqueta: 'Email',
                        controlador: _email,
                        icono: Icons.email_outlined,
                        teclado: TextInputType.emailAddress,
                        autofill: AutofillHints.email,
                        validador: validarEmail,
                      ),
                      _campo(
                        campo: 'telefono',
                        etiqueta: 'Teléfono (opcional)',
                        controlador: _telefono,
                        icono: Icons.phone_outlined,
                        teclado: TextInputType.phone,
                        autofill: AutofillHints.telephoneNumber,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cambiar contraseña (opcional)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completá estos campos solo si querés cambiar tu clave actual.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _campo(
                        campo: 'password_actual',
                        etiqueta: 'Contraseña actual',
                        controlador: _passwordActual,
                        icono: Icons.lock_outline,
                        oculto: true,
                        autofill: AutofillHints.password,
                        validador: (valor) {
                          if (_quiereCambiarPassword &&
                              (valor == null || valor.isEmpty)) {
                            return 'Ingresá tu contraseña actual.';
                          }
                          return null;
                        },
                      ),
                      _campo(
                        campo: 'password',
                        etiqueta: 'Nueva contraseña',
                        ayuda: 'Al menos 8 caracteres',
                        controlador: _password,
                        icono: Icons.lock_reset_outlined,
                        oculto: true,
                        autofill: AutofillHints.newPassword,
                        validador: (valor) {
                          if (!_quiereCambiarPassword) return null;
                          return validarPasswordNueva(valor);
                        },
                      ),
                      _campo(
                        campo: 'password_confirmation',
                        etiqueta: 'Repetir nueva contraseña',
                        controlador: _passwordConfirmacion,
                        icono: Icons.lock_reset_outlined,
                        oculto: true,
                        ultimo: true,
                        validador: (valor) {
                          if (!_quiereCambiarPassword) return null;
                          if (valor != _password.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                      if (_error case final error?) ...[
                        AvisoEnLinea(tipo: TipoAviso.error, mensaje: error),
                        const SizedBox(height: 16),
                      ],
                      FButton(
                        onPress: _enviando ? null : _guardarCambios,
                        child: _enviando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar cambios'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo({
    required String campo,
    required String etiqueta,
    required TextEditingController controlador,
    required IconData icono,
    String? ayuda,
    TextInputType? teclado,
    String? autofill,
    bool oculto = false,
    bool ultimo = false,
    String? Function(String?)? validador,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: oculto
          ? FTextFormField.password(
              control: FTextFieldControl.managed(
                controller: controlador,
                onChange: (_) => _limpiarErrorDelServer(campo),
              ),
              label: Text(etiqueta),
              description: ayuda == null ? null : Text(ayuda),
              prefixBuilder: (context, style, control, variants) =>
                  FTextField.prefixIconBuilder(
                    context,
                    style,
                    variants,
                    Icon(icono),
                  ),
              autofillHints: autofill == null ? const [] : [autofill],
              textInputAction: ultimo
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmit: ultimo ? (_) => _guardarCambios() : null,
              validator: validador,
              forceErrorText: _erroresDelServer[campo],
            )
          : FTextFormField(
              control: FTextFieldControl.managed(
                controller: controlador,
                onChange: (_) => _limpiarErrorDelServer(campo),
              ),
              label: Text(etiqueta),
              description: ayuda == null ? null : Text(ayuda),
              prefixBuilder: (context, style, variants) =>
                  FTextField.prefixIconBuilder(
                    context,
                    style,
                    variants,
                    Icon(icono),
                  ),
              keyboardType: teclado,
              autofillHints: autofill == null ? null : [autofill],
              textInputAction: ultimo
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmit: ultimo ? (_) => _guardarCambios() : null,
              validator: validador,
              forceErrorText: _erroresDelServer[campo],
            ),
    );
  }
}