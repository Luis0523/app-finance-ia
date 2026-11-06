import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../theme/lumina_theme.dart';
import '../../widgets/auth_shell.dart';
import 'forgot_password_screen.dart';
import 'verify_code_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _ModoAuth { login, registro }

class _AuthScreenState extends State<AuthScreen> {
  _ModoAuth _modo = _ModoAuth.login;

  @override
  Widget build(BuildContext context) {
    final esLogin = _modo == _ModoAuth.login;

    return AuthShell(
      titulo: esLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
      subtitulo: esLogin
          ? 'Inicia sesión para gestionar tu negocio.'
          : 'Registra tu negocio y empieza en minutos.',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: esLogin
            ? _LoginForm(
                key: const ValueKey('login'),
                onCrearCuenta: () => setState(() => _modo = _ModoAuth.registro),
              )
            : _RegistroForm(
                key: const ValueKey('registro'),
                onYaTengoCuenta: () => setState(() => _modo = _ModoAuth.login),
              ),
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({required this.onCrearCuenta, super.key});

  final VoidCallback onCrearCuenta;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _ocultarPassword = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    try {
      await auth.iniciarSesion(
        email: _email.text,
        password: _password.text,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = auth.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AuthErrorBanner(mensaje: _error!),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: _validarEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _ocultarPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _entrar(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _ocultarPassword ? 'Mostrar' : 'Ocultar',
                onPressed: () =>
                    setState(() => _ocultarPassword = !_ocultarPassword),
                icon: Icon(
                  _ocultarPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (valor) {
              if (valor == null || valor.isEmpty) {
                return 'Ingresa tu contraseña.';
              }
              return null;
            },
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _cargando
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _cargando ? null : _entrar,
            child: _cargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: LuminaColors.onPrimary,
                    ),
                  )
                : const Text('Iniciar sesión'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _cargando ? null : widget.onCrearCuenta,
            child: const Text('¿No tienes cuenta? Crear una'),
          ),
        ],
      ),
    );
  }
}

class _RegistroForm extends ConsumerStatefulWidget {
  const _RegistroForm({required this.onYaTengoCuenta, super.key});

  final VoidCallback onYaTengoCuenta;

  @override
  ConsumerState<_RegistroForm> createState() => _RegistroFormState();
}

class _RegistroFormState extends ConsumerState<_RegistroForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _nombreNegocio = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  bool _ocultarPassword = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _nombreNegocio.dispose();
    _email.dispose();
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    try {
      final respuesta = await auth.registrar(
        email: _email.text,
        password: _password.text,
        nombre: _nombre.text,
        nombreNegocio: _nombreNegocio.text,
      );

      if (!mounted) return;

      if (respuesta.session == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerifyCodeScreen(
              email: _email.text.trim(),
              tipo: OtpType.signup,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = auth.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AuthErrorBanner(mensaje: _error!),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Tu nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (valor) => (valor == null || valor.trim().isEmpty)
                ? 'Ingresa tu nombre.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nombreNegocio,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nombre del negocio',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            validator: (valor) => (valor == null || valor.trim().isEmpty)
                ? 'Ingresa el nombre de tu negocio.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: _validarEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _ocultarPassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Contraseña',
              helperText: 'Mínimo 6 caracteres.',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _ocultarPassword ? 'Mostrar' : 'Ocultar',
                onPressed: () =>
                    setState(() => _ocultarPassword = !_ocultarPassword),
                icon: Icon(
                  _ocultarPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (valor) {
              if (valor == null || valor.length < 6) {
                return 'Usa al menos 6 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmar,
            obscureText: _ocultarPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _registrar(),
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
            validator: (valor) {
              if (valor != _password.text) {
                return 'Las contraseñas no coinciden.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _cargando ? null : _registrar,
            child: _cargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: LuminaColors.onPrimary,
                    ),
                  )
                : const Text('Crear cuenta'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _cargando ? null : widget.onYaTengoCuenta,
            child: const Text('¿Ya tienes cuenta? Iniciar sesión'),
          ),
        ],
      ),
    );
  }
}

String? _validarEmail(String? valor) {
  final email = valor?.trim() ?? '';
  if (email.isEmpty) return 'Ingresa tu correo.';
  final patron = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!patron.hasMatch(email)) return 'Ingresa un correo válido.';
  return null;
}
