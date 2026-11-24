import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../sesion/sesion.dart';
import '../validaciones.dart';
import '../tema/tema_app.dart';
import '../widgets/componentes_ui.dart';

class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _dni = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmacion = TextEditingController();

  bool _enviando = false;
  String? _error;

  /// Errores que devolvió el server, por campo. Se muestran debajo de cada uno.
  Map<String, String> _erroresDelServer = {};
  Map<String, List<String>> _todosLosErrores = {};

  @override
  void dispose() {
    for (final campo in [
      _nombre,
      _apellido,
      _dni,
      _email,
      _telefono,
      _password,
      _passwordConfirmacion,
    ]) {
      campo.dispose();
    }
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    setState(() {
      _error = null;
      _erroresDelServer = {};
      _todosLosErrores = {};
    });
    if (!_formulario.currentState!.validate()) {
      return;
    }

    setState(() => _enviando = true);
    try {
      await widget.sesion.registrarse(
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        dni: limpiarDni(_dni.text),
        email: _email.text.trim(),
        telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
        password: _password.text,
        passwordConfirmacion: _passwordConfirmacion.text,
      );
      // La sesión ya quedó iniciada: se cierra esta pantalla y debajo
      // aparece la de inicio.
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.errores.isEmpty && error.todosLosErrores.isEmpty
              ? error.mensaje
              : null;
          _erroresDelServer = error.errores;
          _todosLosErrores = error.todosLosErrores.isNotEmpty
              ? error.todosLosErrores
              : error.errores.map(
                  (campo, mensaje) => MapEntry(campo, [mensaje]),
                );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  /// Al corregir un campo, deja de mostrarse el error que había marcado el server.
  void _limpiarErrorDelServer(String campo) {
    if (_erroresDelServer.containsKey(campo) ||
        _todosLosErrores.containsKey(campo)) {
      setState(() {
        _erroresDelServer = {..._erroresDelServer}..remove(campo);
        _todosLosErrores = {..._todosLosErrores}..remove(campo);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TemaApp(
      child: LayoutPagina(
        titulo: 'Crear cuenta',
        alVolver: () {
          if (!_enviando) Navigator.of(context).pop();
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
                          campo: 'dni',
                          etiqueta: 'DNI',
                          ayuda: 'Solo números, con o sin puntos',
                          controlador: _dni,
                          icono: Icons.badge_outlined,
                          teclado: TextInputType.number,
                          validador: validarDni,
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
                        _campo(
                          campo: 'password',
                          etiqueta: 'Contraseña',
                          ayuda: 'Al menos 8 caracteres',
                          controlador: _password,
                          icono: Icons.lock_outline,
                          oculto: true,
                          autofill: AutofillHints.newPassword,
                          validador: validarPasswordNueva,
                        ),
                        _campo(
                          campo: 'password_confirmation',
                          etiqueta: 'Repetir contraseña',
                          controlador: _passwordConfirmacion,
                          icono: Icons.lock_outline,
                          oculto: true,
                          ultimo: true,
                          validador: (valor) => valor != _password.text
                              ? 'Las contraseñas no coinciden.'
                              : null,
                        ),
                        if (_error != null || _todosLosErrores.isNotEmpty) ...[
                          AvisoEnLinea(
                            tipo: TipoAviso.error,
                            mensaje:
                                _error ??
                                _todosLosErrores.values
                                    .expand((mensajes) => mensajes)
                                    .map((mensaje) => '• $mensaje')
                                    .join('\n'),
                          ),
                          const SizedBox(height: 16),
                        ],
                        FButton(
                          onPress: _enviando ? null : _crearCuenta,
                          child: _enviando
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Crear cuenta'),
                        ),
                        const SizedBox(height: 8),
                        FButton(
                          variant: .ghost,
                          onPress: _enviando
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('¿Ya tenés cuenta? Iniciá sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Un campo del formulario. [campo] es el nombre que usa el server, para
  /// mostrar debajo el error que devuelva.
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
              onSubmit: ultimo ? (_) => _crearCuenta() : null,
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
              onSubmit: ultimo ? (_) => _crearCuenta() : null,
              validator: validador,
              forceErrorText: _erroresDelServer[campo],
            ),
    );
  }
}
