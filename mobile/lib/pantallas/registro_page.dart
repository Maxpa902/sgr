import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../sesion/sesion.dart';
import '../validaciones.dart';
import '../widgets/mensaje_error.dart';

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

  /// Al corregir un campo, deja de mostrarse el error que había marcado el server.
  void _limpiarErrorDelServer(String campo) {
    if (_erroresDelServer.containsKey(campo)) {
      setState(() => _erroresDelServer = {..._erroresDelServer}..remove(campo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                      if (_error case final error?) ...[
                        MensajeError(error),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        onPressed: _enviando ? null : _crearCuenta,
                        child: _enviando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Crear cuenta'),
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
      child: TextFormField(
        controller: controlador,
        decoration: InputDecoration(
          labelText: etiqueta,
          helperText: ayuda,
          prefixIcon: Icon(icono),
          border: const OutlineInputBorder(),
        ),
        keyboardType: teclado,
        obscureText: oculto,
        autofillHints: autofill == null ? null : [autofill],
        textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: ultimo ? (_) => _crearCuenta() : null,
        onChanged: (_) => _limpiarErrorDelServer(campo),
        validator: validador,
        forceErrorText: _erroresDelServer[campo],
      ),
    );
  }
}
