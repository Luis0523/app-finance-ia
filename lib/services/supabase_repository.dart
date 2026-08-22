import 'package:supabase/supabase.dart';

import '../models/flujo_caja.dart';
import '../models/listado_transaccion.dart';
import '../models/producto_inventario.dart';
import '../models/resumen_analisis.dart';
import '../models/totales_mes.dart';
import '../models/ultima_transaccion.dart';

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

  Future<TotalesMes> obtenerTotalesMes();

  Future<ResumenAnalisis> obtenerResumenAnalisis();

  Future<UltimaTransaccion?> ultimaTransaccion({String? tipo});

  Future<List<ListadoTransaccion>> listadoTransacciones({
    String? tipo,
    int limite = 50,
  });

  Future<List<FlujoDia>> flujoCaja();

  Future<List<ProductoInventario>> inventario();
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

    // Identifica la sesión para que RLS filtre por negocio.
    _client.rest.headers['x-negocio-id'] = _negocioId!;

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

  @override
  Future<TotalesMes> obtenerTotalesMes() async {
    await _asegurarDatosPrueba();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_totales_mes',
      params: {'p_negocio_id': negocioId},
    );

    final row = _filaDe(rows);
    if (row == null) {
      return const TotalesMes(
        ingresos: 0,
        egresos: 0,
        cantidadIngresos: 0,
        cantidadEgresos: 0,
      );
    }

    return TotalesMes(
      ingresos: (row['ingresos'] as num?)?.toDouble() ?? 0,
      egresos: (row['egresos'] as num?)?.toDouble() ?? 0,
      cantidadIngresos: (row['cantidad_ingresos'] as num?)?.toInt() ?? 0,
      cantidadEgresos: (row['cantidad_egresos'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<ResumenAnalisis> obtenerResumenAnalisis() async {
    await _asegurarDatosPrueba();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_resumen_analisis',
      params: {'p_negocio_id': negocioId},
    );

    final row = _filaDe(rows);
    if (row == null) return ResumenAnalisis.vacio();

    final porCategoria = (row['por_categoria'] as List<dynamic>? ?? [])
        .map((item) {
          final e = item as Map<String, dynamic>;
          return ResumenCategoria(
            categoriaNivel1: e['categoria_nivel1']?.toString() ?? '',
            categoriaNivel2: e['categoria_nivel2']?.toString() ?? '',
            tipo: e['tipo']?.toString() ?? '',
            total: (e['total'] as num?)?.toDouble() ?? 0,
            cantidad: (e['cantidad'] as num?)?.toInt() ?? 0,
          );
        })
        .toList();

    return ResumenAnalisis(
      ingresos: (row['ingresos'] as num?)?.toDouble() ?? 0,
      egresos: (row['egresos'] as num?)?.toDouble() ?? 0,
      cantidadIngresos: (row['cantidad_ingresos'] as num?)?.toInt() ?? 0,
      cantidadEgresos: (row['cantidad_egresos'] as num?)?.toInt() ?? 0,
      porCategoria: porCategoria,
    );
  }

  @override
  Future<UltimaTransaccion?> ultimaTransaccion({String? tipo}) async {
    await _asegurarDatosPrueba();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_ultima_transaccion',
      params: {
        'p_negocio_id': negocioId,
        'p_tipo': ?tipo,
      },
    );

    final row = _filaDe(rows);
    if (row == null) return null;

    return UltimaTransaccion(
      monto: (row['monto'] as num?)?.toDouble() ?? 0,
      tipo: row['tipo']?.toString() ?? '',
      fecha: DateTime.tryParse(row['fecha']?.toString() ?? '') ?? DateTime.now(),
      descripcion: row['descripcion_normalizada']?.toString(),
      categoriaNivel1: row['categoria_nivel1']?.toString(),
      categoriaNivel2: row['categoria_nivel2']?.toString(),
    );
  }

  /// Los RPC que devuelven `jsonb` regresan un Map directo; los que devuelven
  /// tabla regresan una lista. Normaliza a un mapa único o null.
  Map<String, dynamic>? _filaDe(dynamic rows) {
    if (rows == null) return null;
    if (rows is Map) return Map<String, dynamic>.from(rows);
    if (rows is List) {
      if (rows.isEmpty) return null;
      final first = rows.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  List<Map<String, dynamic>> _filasDe(dynamic rows) {
    if (rows is! List) return const [];
    return rows.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<List<ListadoTransaccion>> listadoTransacciones({
    String? tipo,
    int limite = 50,
  }) async {
    await _asegurarDatosPrueba();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_listado_transacciones',
      params: {
        'p_negocio_id': negocioId,
        'p_tipo': ?tipo,
        'p_limite': limite,
      },
    );

    return _filasDe(rows).map((row) {
      return ListadoTransaccion(
        fecha:
            DateTime.tryParse(row['fecha']?.toString() ?? '') ?? DateTime.now(),
        tipo: row['tipo']?.toString() ?? '',
        monto: (row['monto'] as num?)?.toDouble() ?? 0,
        categoriaNivel1: row['categoria_nivel1']?.toString(),
        categoriaNivel2: row['categoria_nivel2']?.toString(),
        descripcion: row['descripcion']?.toString(),
        origen: row['origen']?.toString(),
      );
    }).toList();
  }

  @override
  Future<List<FlujoDia>> flujoCaja() async {
    await _asegurarDatosPrueba();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_flujo_caja',
      params: {'p_negocio_id': negocioId},
    );

    return _filasDe(rows).map((row) {
      return FlujoDia(
        fecha:
            DateTime.tryParse(row['fecha']?.toString() ?? '') ?? DateTime.now(),
        ingresos: (row['ingresos'] as num?)?.toDouble() ?? 0,
        egresos: (row['egresos'] as num?)?.toDouble() ?? 0,
        balance: (row['balance'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<ProductoInventario>> inventario() async {
    await _asegurarDatosPrueba();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_inventario',
      params: {'p_negocio_id': negocioId},
    );

    return _filasDe(rows).map((row) {
      return ProductoInventario(
        nombre: row['nombre']?.toString() ?? '',
        precioCompra: (row['precio_compra'] as num?)?.toDouble() ?? 0,
        precioVenta: (row['precio_venta'] as num?)?.toDouble() ?? 0,
        existencias: (row['existencias'] as num?)?.toDouble() ?? 0,
        valorTotal: (row['valor_total'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }
}
