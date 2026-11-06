import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Future<AuthResponse> iniciarSesion({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> registrar({
    required String email,
    required String password,
    required String nombre,
    required String nombreNegocio,
  }) {
    return _auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'nombre': nombre.trim(),
        'nombre_negocio': nombreNegocio.trim(),
      },
    );
  }

  Future<void> cerrarSesion() => _auth.signOut();

  Future<void> enviarCodigoRecuperacion(String email) {
    return _auth.resetPasswordForEmail(email.trim());
  }

  Future<AuthResponse> verificarCodigo({
    required String email,
    required String codigo,
    required OtpType tipo,
  }) {
    return _auth.verifyOTP(
      email: email.trim(),
      token: codigo.trim(),
      type: tipo,
    );
  }

  Future<void> reenviarCodigo({
    required String email,
    required OtpType tipo,
  }) {
    return _auth.resend(email: email.trim(), type: tipo);
  }

  Future<void> actualizarPassword(String password) {
    return _auth.updateUser(UserAttributes(password: password));
  }

  String mensajeError(Object error) {
    if (error is! AuthException) {
      return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }

    final mensaje = error.message.toLowerCase();

    if (mensaje.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (mensaje.contains('email not confirmed')) {
      return 'Debes confirmar tu correo antes de iniciar sesión.';
    }
    if (mensaje.contains('already registered') ||
        mensaje.contains('already been registered') ||
        mensaje.contains('user already exists')) {
      return 'Ya existe una cuenta con este correo.';
    }
    if (mensaje.contains('password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (mensaje.contains('token has expired') ||
        mensaje.contains('invalid token') ||
        mensaje.contains('otp')) {
      return 'El código no es válido o expiró. Solicita uno nuevo.';
    }
    if (mensaje.contains('for security purposes') ||
        mensaje.contains('rate limit') ||
        mensaje.contains('too many requests')) {
      return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
    }
    if (mensaje.contains('unable to validate email') ||
        mensaje.contains('invalid email')) {
      return 'El correo electrónico no es válido.';
    }
    if (mensaje.contains('signups not allowed') ||
        mensaje.contains('signup is disabled')) {
      return 'El registro está deshabilitado temporalmente.';
    }
    if (mensaje.contains('user not found')) {
      return 'No encontramos una cuenta con este correo.';
    }

    return error.message;
  }
}
