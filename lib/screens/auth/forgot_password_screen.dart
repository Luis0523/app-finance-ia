import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../theme/lumina_theme.dart';
import '../../widgets/auth_shell.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Paso { correo, codigo }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _codigoForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  _Paso _paso = _Paso.correo;
  bool _cargando = false;
  bool _ocultarPassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    if (!_emailForm.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    try {
      await auth.enviarCodigoRecuperacion(_email.text);
      if (!mounted) return;
      setState(() => _paso = _Paso.codigo);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enviamos un código de recuperación a ${_email.text}.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = auth.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarPassword() async {
    if (!_codigoForm.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    var sesionVerificada = false;
    try {
      final respuesta = await auth.verificarCodigo(
        email: _email.text,
        codigo: _codigo.text,
        tipo: OtpType.recovery,
      );
      sesionVerificada = respuesta.session != null;

      if (!sesionVerificada) {
        throw const AuthException('No se pudo verificar el código.');
      }

      await auth.actualizarPassword(_password.text);
      await auth.cerrarSesion();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada. Inicia sesión de nuevo.'),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (sesionVerificada) {
        try {
          await auth.cerrarSesion();
        } catch (_) {
          // Si falla el cierre de sesión, el usuario puede volver a intentarlo.
        }
      }
      if (mounted) {
        setState(() => _error = auth.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esCorreo = _paso == _Paso.correo;

    return AuthShell(
      titulo: esCorreo ? 'Recuperar contraseña' : 'Nueva contraseña',
      subtitulo: esCorreo
          ? 'Escribe tu correo y te enviaremos un código de 6 dígitos.'
          : 'Ingresa el código enviado a ${_email.text} y define tu nueva contraseña.',
      onVolver: () {
        if (esCorreo) {
          Navigator.of(context).maybePop();
        } else {
          setState(() {
            _paso = _Paso.correo;
            _error = null;
            _codigo.clear();
          });
        }
      },
      child: esCorreo ? _formCorreo() : _formCodigo(),
    );
  }

  Widget _formCorreo() {
    return Form(
      key: _emailForm,
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
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            onFieldSubmitted: (_) => _enviarCodigo(),
            validator: (valor) {
              final email = valor?.trim() ?? '';
              if (email.isEmpty) return 'Ingresa tu correo.';
              final patron = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!patron.hasMatch(email)) return 'Ingresa un correo válido.';
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _cargando ? null : _enviarCodigo,
            child: _cargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: LuminaColors.onPrimary,
                    ),
                  )
                : const Text('Enviar código'),
          ),
        ],
      ),
    );
  }

  Widget _formCodigo() {
    return Form(
      key: _codigoForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AuthErrorBanner(mensaje: _error!),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _codigo,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 8,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'Código',
              counterText: '',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            validator: (valor) {
              if (valor == null || valor.trim().length != 6) {
                return 'Ingresa el código de 6 dígitos.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _ocultarPassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
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
            onFieldSubmitted: (_) => _cambiarPassword(),
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
            onPressed: _cargando ? null : _cambiarPassword,
            child: _cargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: LuminaColors.onPrimary,
                    ),
                  )
                : const Text('Cambiar contraseña'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _cargando ? null : _enviarCodigo,
            child: const Text('Reenviar código'),
          ),
        ],
      ),
    );
  }
}
