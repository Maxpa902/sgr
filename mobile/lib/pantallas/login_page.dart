import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../api/api_exception.dart';
import '../mapa/zona.dart';
import '../sesion/sesion.dart';
import '../validaciones.dart';
import '../widgets/mensaje_error.dart';
import 'registro_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formulario.currentState!.validate()) {
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await widget.sesion.iniciarSesion(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Si sale bien, la sesión avisa el cambio y la app pasa sola al inicio.
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.errores.values.firstOrNull ?? error.mensaje,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  void _irARegistro() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegistroPage(sesion: widget.sesion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return FScaffold(
      childPad: false,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formulario,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.location_city, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'SGR',
                        textAlign: TextAlign.center,
                        style: textos.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reclamos de servicios en ${ZonaDelMapa.nombre}',
                        textAlign: TextAlign.center,
                        style: textos.bodyLarge,
                      ),
                      const SizedBox(height: 32),
                      FTextFormField(
                        control: FTextFieldControl.managed(controller: _email),
                        label: const Text('Email'),
                        prefixBuilder: (context, style, variants) =>
                            FTextField.prefixIconBuilder(
                              context,
                              style,
                              variants,
                              const Icon(Icons.email_outlined),
                            ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: validarEmail,
                      ),
                      const SizedBox(height: 16),
                      FTextFormField.password(
                        control: FTextFieldControl.managed(
                          controller: _password,
                        ),
                        label: const Text('Contraseña'),
                        prefixBuilder: (context, style, control, variants) =>
                            FTextField.prefixIconBuilder(
                              context,
                              style,
                              variants,
                              const Icon(Icons.lock_outline),
                            ),
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmit: (_) => _ingresar(),
                        validator: obligatorio('Ingresá tu contraseña.'),
                      ),
                      if (_error case final error?) ...[
                        const SizedBox(height: 16),
                        MensajeError(error),
                      ],
                      const SizedBox(height: 24),
                      FButton(
                        onPress: _enviando ? null : _ingresar,
                        child: _enviando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Ingresar'),
                      ),
                      const SizedBox(height: 12),
                      FButton(
                        variant: .ghost,
                        onPress: _enviando ? null : _irARegistro,
                        child: const Text('¿No tenés cuenta? Creá una'),
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
}
