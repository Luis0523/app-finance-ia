import 'package:supabase/supabase.dart';

class PersistException implements Exception {
  PersistException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class FinanzasRepository {
  Future<String> buscarOCrearCategoriaNivel2({
    required String categoriaNivel1,
    required String categoriaNivel2,
    required String tipo,
  });

  Future<String> insertarTransaccion({
    required String categoriaId,
    required double monto,
    required String tipo,
    required String descripcionOriginal,
    required String descripcionNormalizada,
    required String origen,
    required double confianza,
  });

  Future<String> insertarConversacion({
    required String mensajeUsuario,
    required String intencion,
    required String? respuestaSistema,
  });

  Future<void> actualizarTransaccionEnConversacion({
    required String conversacionId,
    required String transaccionId,
  });
}

class SupabaseRepository implements FinanzasRepository {
  SupabaseRepository(this._client);

  final SupabaseClient _client;

  String? _negocioId;
  String? _usuarioId;

  Future<void> _asegurarDatosPrueba() async {
    if (_negocioId != null && _usuarioId != null) return;

    final negocios = await _client
        .from('negocios')
        .select('id')
        .order('creado_en')
        .limit(1);
    if (negocios.isEmpty) {
      throw PersistException(
        'No hay un negocio de prueba sembrado. Ejecuta supabase/seed.sql.',
      );
    }
    _negocioId = negocios.first['id'] as String;

    final usuarios = await _client
        .from('usuarios')
        .select('id')
        .eq('negocio_id', _negocioId!)
        .limit(1);
    if (usuarios.isEmpty) {
      throw PersistException('No hay un usuario de prueba para el negocio.');
    }
    _usuarioId = usuarios.first['id'] as String;
  }

  @override
  @override
  Future<String> buscarOCrearCategoriaNivel2({
    required String categoriaNivel1,
    required String categoriaNivel2,
    required String tipo,
  }) async {
    await _asegurarDatosPrueba();
    final negocioId = _negocioId!;

    final padres = await _client
        .from('categorias')
        .select('id')
        .isFilter('negocio_id', null)
        .isFilter('categoria_padre_id', null)
        .eq('nombre', categoriaNivel1)
        .limit(1);
    if (padres.isEmpty) {
      throw PersistException('Categoría nivel 1 no encontrada: $categoriaNivel1');
    }
    final padreId = padres.first['id'] as String;

    final existentes = await _client
        .from('categorias')
        .select('id')
        .eq('negocio_id', negocioId)
        .eq('categoria_padre_id', padreId)
        .eq('nombre', categoriaNivel2)
        .limit(1);
    if (existentes.isNotEmpty) {
      return existentes.first['id'] as String;
    }

    try {
      final insertados = await _client
          .from('categorias')
          .insert({
            'negocio_id': negocioId,
            'categoria_padre_id': padreId,
            'nombre': categoriaNivel2,
            'tipo': tipo,
          })
          .select('id');
      return insertados.first['id'] as String;
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
      final reconsulta = await _client
          .from('categorias')
          .select('id')
          .eq('negocio_id', negocioId)
          .eq('categoria_padre_id', padreId)
          .eq('nombre', categoriaNivel2)
          .limit(1);
      return reconsulta.first['id'] as String;
    }
  }

  @override
  Future<String> insertarTransaccion({
    required String categoriaId,
    required double monto,
    required String tipo,
    required String descripcionOriginal,
    required String descripcionNormalizada,
    required String origen,
    required double confianza,
  }) async {
    await _asegurarDatosPrueba();
    final negocioId = _negocioId!;

    final insertados = await _client
        .from('transacciones')
        .insert({
          'negocio_id': negocioId,
          'categoria_id': categoriaId,
          'monto': monto,
          'tipo': tipo,
          'descripcion_original': descripcionOriginal,
          'descripcion_normalizada': descripcionNormalizada,
          'origen': origen,
          'confianza_clasificacion': confianza,
          'confirmado_por_usuario': true,
        })
        .select('id');

    return insertados.first['id'] as String;
  }

  @override
  Future<String> insertarConversacion({
    required String mensajeUsuario,
    required String intencion,
    required String? respuestaSistema,
  }) async {
    await _asegurarDatosPrueba();
    final usuarioId = _usuarioId!;

    final insertados = await _client
        .from('conversaciones')
        .insert({
          'usuario_id': usuarioId,
          'mensaje_usuario': mensajeUsuario,
          'intencion_detectada': intencion,
          'respuesta_sistema': respuestaSistema,
        })
        .select('id');

    return insertados.first['id'] as String;
  }

  @override
  Future<void> actualizarTransaccionEnConversacion({
    required String conversacionId,
    required String transaccionId,
  }) async {
    await _client
        .from('conversaciones')
        .update({'transaccion_id': transaccionId})
        .eq('id', conversacionId);
  }
}
