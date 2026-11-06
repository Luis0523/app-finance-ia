import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../theme/lumina_theme.dart';
import '../../widgets/auth_shell.dart';

class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({
    required this.email,
    required this.tipo,
    super.key,
  });

  final String email;
  final OtpType tipo;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  bool _cargando = false;
  bool _reenviando = false;
  int _segundosParaReenviar = 0;
  Timer? _temporizador;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iniciarContador();
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  void _iniciarContador() {
    _temporizador?.cancel();
    setState(() => _segundosParaReenviar = 60);
    _temporizador = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosParaReenviar <= 1) {
        timer.cancel();
        setState(() => _segundosParaReenviar = 0);
      } else {
        setState(() => _segundosParaReenviar--);
      }
    });
  }

  Future<void> _verificar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    try {
      final respuesta = await auth.verificarCodigo(
        email: widget.email,
        codigo: _codigo.text,
        tipo: widget.tipo,
      );

      if (!mounted) return;

      if (respuesta.session == null) {
        setState(() => _error = 'No se pudo verificar el código.');
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        setState(() => _error = auth.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviar() async {
    if (_segundosParaReenviar > 0 || _reenviando) return;

    setState(() {
      _reenviando = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    try {
      await auth.reenviarCodigo(email: widget.email, tipo: widget.tipo);
      if (!mounted) return;
      _iniciarContador();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enviamos un nuevo código a ${widget.email}.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = auth.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      titulo: 'Confirma tu correo',
      subtitulo:
          'Enviamos un código de 6 dígitos a ${widget.email}. Ingrésalo para activar tu cuenta.',
      onVolver: () => Navigator.of(context).maybePop(),
      child: Form(
        key: _formKey,
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
              textInputAction: TextInputAction.done,
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
              onFieldSubmitted: (_) => _verificar(),
              validator: (valor) {
                if (valor == null || valor.trim().length != 6) {
                  return 'Ingresa el código de 6 dígitos.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cargando ? null : _verificar,
              child: _cargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LuminaColors.onPrimary,
                      ),
                    )
                  : const Text('Verificar cuenta'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: (_reenviando || _segundosParaReenviar > 0)
                  ? null
                  : _reenviar,
              child: Text(
                _segundosParaReenviar > 0
                    ? 'Reenviar código en $_segundosParaReenviar s'
                    : 'Reenviar código',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
