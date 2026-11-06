import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

import '../models/cuenta_por_cobrar.dart';
import '../models/flujo_caja.dart';
import '../models/item_venta_pos.dart';
import '../models/listado_transaccion.dart';
import '../models/movimiento_kardex.dart';
import '../models/producto_inventario.dart';
import '../models/proveedor.dart';
import '../models/resumen_analisis.dart';
import '../models/resumen_ganancias.dart';
import '../models/sugerencia_pedido_proveedor.dart';
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
    double? cantidad,
    double? precioUnitario,
    String? productoId,
  });

  Future<bool> registrarVentaPos({
    required List<ItemVentaPos> items,
    required String metodoPago,
    String? notas,
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

  Future<ResumenGanancias> obtenerResumenGanancias();

  Future<String?> buscarOCrearProducto({
    required String nombre,
    double? precioCompra,
    double? precioVenta,
    String unidadMedida = 'unidad',
    String tipoProducto = 'reventa',
  });

  Future<String?> registrarCompra({
    required String productoId,
    required double cantidad,
    required double costoUnitario,
    String? proveedor,
    String? transaccionId,
  });

  Future<bool> actualizarProducto({
    required String nombre,
    double? precioVenta,
    double? precioCompra,
    double? stockMinimo,
  });

  Future<bool> actualizarProductoPorId({
    required String productoId,
    String? nuevoNombre,
    double? precioVenta,
    double? precioCompra,
    double? stockMinimo,
    double? stockMaximo,
    String? unidadMedida,
    String? categoriaProducto,
    String? codigoBarras,
    String? imagenUrl,
    String? proveedorId,
  });

  Future<bool> ajustarInventario({
    required String nombre,
    required double cantidadObjetivo,
  });

  Future<bool> ajustarInventarioConMotivo({
    required String productoId,
    required double cantidadObjetivo,
    String motivo = 'Ajuste manual',
  });

  Future<List<Proveedor>> obtenerProveedores();

  Future<Proveedor?> crearProveedor({
    required String nombre,
    String? contacto,
    String? telefono,
    String? direccion,
    String? diasVisita,
    String? notas,
  });

  Future<bool> actualizarProveedor(Proveedor proveedor);

  Future<bool> eliminarProveedor(String id);

  Future<List<MovimientoKardex>> obtenerKardexProducto({
    required String productoId,
    int limite = 30,
  });

  Future<String?> subirImagenProducto({
    required List<int> bytes,
    required String extension,
  });

  Future<List<CuentaPorCobrar>> obtenerCuentasPorCobrar({String? estado});

  Future<CuentaPorCobrar?> registrarFiado({
    required String clienteNombre,
    required double monto,
    String? descripcion,
    String? clienteTelefono,
    DateTime? fechaLimite,
    String? transaccionId,
  });

  Future<bool> registrarAbonoFiado({
    required String cuentaId,
    required double monto,
    String metodoPago = 'efectivo',
    String? notas,
  });

  Future<List<SugerenciaPedidoProveedor>> obtenerSugerenciasPedidosProveedores();

  Future<String?> registrarGastoManual({
    required double monto,
    required String categoriaNivel1,
    String? categoriaNivel2,
    required String descripcion,
    String? metodoPago,
  });
}

class SupabaseRepository implements FinanzasRepository {
  SupabaseRepository(this._client);

  final SupabaseClient _client;

  String? _negocioId;
  String? _usuarioId;

  Future<void> _asegurarSesion() async {
    if (_negocioId != null && _usuarioId != null) return;

    final user = _client.auth.currentUser;
    if (user == null) {
      throw PersistException('Tu sesión expiró. Inicia sesión de nuevo.');
    }

    final usuarios = await _client
        .from('usuarios')
        .select('id, negocio_id')
        .eq('auth_user_id', user.id)
        .limit(1);
    if (usuarios.isEmpty) {
      throw PersistException(
        'Tu usuario no tiene un negocio asociado. Completa tu registro.',
      );
    }

    _usuarioId = usuarios.first['id'] as String;
    _negocioId = usuarios.first['negocio_id'] as String;

    // Compatibilidad con la política RLS anterior. La política nueva
    // identifica el negocio a partir de la sesión de Supabase Auth.
    _client.rest.headers['x-negocio-id'] = _negocioId!;
  }

  @override
  Future<String> buscarOCrearCategoriaNivel2({
    required String categoriaNivel1,
    required String categoriaNivel2,
    required String tipo,
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final padres = await _client
        .from('categorias')
        .select('id')
        .isFilter('negocio_id', null)
        .isFilter('categoria_padre_id', null)
        .eq('nombre', categoriaNivel1)
        .limit(1);
    if (padres.isEmpty) {
      throw PersistException(
        'Categoría nivel 1 no encontrada: $categoriaNivel1',
      );
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
    double? cantidad,
    double? precioUnitario,
    String? productoId,
  }) async {
    await _asegurarSesion();
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
          'cantidad': ?cantidad,
          'precio_unitario': ?precioUnitario,
          'producto_id': ?productoId,
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
    await _asegurarSesion();
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
    await _asegurarSesion();
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
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_resumen_analisis',
      params: {'p_negocio_id': negocioId},
    );

    final row = _filaDe(rows);
    if (row == null) return ResumenAnalisis.vacio();

    final porCategoria = (row['por_categoria'] as List<dynamic>? ?? []).map((
      item,
    ) {
      final e = item as Map<String, dynamic>;
      return ResumenCategoria(
        categoriaNivel1: e['categoria_nivel1']?.toString() ?? '',
        categoriaNivel2: e['categoria_nivel2']?.toString() ?? '',
        tipo: e['tipo']?.toString() ?? '',
        total: (e['total'] as num?)?.toDouble() ?? 0,
        cantidad: (e['cantidad'] as num?)?.toInt() ?? 0,
      );
    }).toList();

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
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_ultima_transaccion',
      params: {'p_negocio_id': negocioId, 'p_tipo': ?tipo},
    );

    final row = _filaDe(rows);
    if (row == null) return null;

    return UltimaTransaccion(
      monto: (row['monto'] as num?)?.toDouble() ?? 0,
      tipo: row['tipo']?.toString() ?? '',
      fecha:
          DateTime.tryParse(row['fecha']?.toString() ?? '') ?? DateTime.now(),
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
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_listado_transacciones',
      params: {'p_negocio_id': negocioId, 'p_tipo': ?tipo, 'p_limite': limite},
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
        cantidad: (row['cantidad'] as num?)?.toDouble(),
        precioUnitario: (row['precio_unitario'] as num?)?.toDouble(),
        costoUnitarioMomentoVenta: (row['costo_unitario_momento_venta'] as num?)
            ?.toDouble(),
        utilidad: (row['utilidad_calculada'] as num?)?.toDouble(),
      );
    }).toList();
  }

  @override
  Future<List<FlujoDia>> flujoCaja() async {
    await _asegurarSesion();
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
    await _asegurarSesion();
    final negocioId = _negocioId!;

    try {
      final rows = await _client.rpc(
        'obtener_inventario',
        params: {'p_negocio_id': negocioId},
      );

      return _filasDe(rows).map((row) {
        return ProductoInventario(
          id: row['id']?.toString(),
          nombre: row['nombre']?.toString() ?? '',
          imagenUrl: row['imagen_url']?.toString(),
          codigoBarras: row['codigo_barras']?.toString(),
          categoriaProducto: row['categoria_producto']?.toString(),
          unidadMedida: row['unidad_medida']?.toString() ?? 'unidad',
          precioCompra: (row['precio_compra'] as num?)?.toDouble() ?? 0,
          precioVenta: (row['precio_venta'] as num?)?.toDouble() ?? 0,
          existencias: (row['existencias'] as num?)?.toDouble() ?? 0,
          costoPromedio: (row['costo_promedio'] as num?)?.toDouble(),
          utilidadUnitaria: (row['utilidad_unitaria'] as num?)?.toDouble(),
          valorTotal: (row['valor_total'] as num?)?.toDouble() ?? 0,
          stockMinimo: (row['stock_minimo'] as num?)?.toDouble(),
          stockMaximo: (row['stock_maximo'] as num?)?.toDouble(),
          proveedorId: row['proveedor_id']?.toString(),
          proveedorNombre: row['proveedor_nombre']?.toString(),
          estado: row['estado']?.toString(),
        );
      }).toList();
    } catch (_) {
      // Fallback directo a tablas si el RPC tiene discrepancia de esquema
      final prods = await _client
          .from('productos')
          .select('*, inventario(*), proveedores(nombre)')
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .order('nombre');

      return (prods as List).map((p) {
        final m = Map<String, dynamic>.from(p);
        final inv = m['inventario'] is Map ? Map<String, dynamic>.from(m['inventario']) : null;
        final prov = m['proveedores'] is Map ? Map<String, dynamic>.from(m['proveedores']) : null;
        final exist = (inv?['existencia_actual'] as num?)?.toDouble() ?? 0;
        final costo = (inv?['costo_promedio_actual'] as num?)?.toDouble();
        final pVenta = (m['precio_venta'] as num?)?.toDouble() ?? 0;
        final sMin = (m['stock_minimo'] as num?)?.toDouble();

        String estado = 'ok';
        if (exist <= 0) {
          estado = 'agotado';
        } else if (sMin != null && exist <= sMin) {
          estado = 'bajo';
        }

        return ProductoInventario(
          id: m['id']?.toString(),
          nombre: m['nombre']?.toString() ?? '',
          imagenUrl: m['imagen_url']?.toString(),
          codigoBarras: m['codigo_barras']?.toString(),
          categoriaProducto: m['categoria_producto']?.toString(),
          unidadMedida: m['unidad_medida']?.toString() ?? 'unidad',
          precioCompra: (m['precio_compra'] as num?)?.toDouble() ?? 0,
          precioVenta: pVenta,
          existencias: exist,
          costoPromedio: costo,
          utilidadUnitaria: costo != null ? pVenta - costo : null,
          valorTotal: exist * (costo ?? (m['precio_compra'] as num?)?.toDouble() ?? 0),
          stockMinimo: sMin,
          stockMaximo: (m['stock_maximo'] as num?)?.toDouble(),
          proveedorId: m['proveedor_id']?.toString(),
          proveedorNombre: prov?['nombre']?.toString(),
          estado: estado,
        );
      }).toList();
    }
  }

  @override
  Future<ResumenGanancias> obtenerResumenGanancias() async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final rows = await _client.rpc(
      'obtener_resumen_ganancias',
      params: {'p_negocio_id': negocioId},
    );

    final row = _filaDe(rows);
    if (row == null) {
      return const ResumenGanancias(
        ingresos: 0,
        costoVentas: 0,
        utilidad: 0,
        cantidadVentas: 0,
        margen: 0,
      );
    }

    return ResumenGanancias(
      ingresos: (row['ingresos'] as num?)?.toDouble() ?? 0,
      costoVentas: (row['costo_ventas'] as num?)?.toDouble() ?? 0,
      utilidad: (row['utilidad'] as num?)?.toDouble() ?? 0,
      cantidadVentas: (row['cantidad_ventas'] as num?)?.toInt() ?? 0,
      margen: (row['margen'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<String?> buscarOCrearProducto({
    required String nombre,
    double? precioCompra,
    double? precioVenta,
    String unidadMedida = 'unidad',
    String tipoProducto = 'reventa',
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final result = await _client.rpc(
      'buscar_o_crear_producto',
      params: {
        'p_negocio_id': negocioId,
        'p_nombre': nombre,
        'p_precio_compra': ?precioCompra,
        'p_precio_venta': ?precioVenta,
        'p_unidad_medida': unidadMedida,
        'p_tipo_producto': tipoProducto,
      },
    );

    return result?.toString();
  }

  @override
  Future<String?> registrarCompra({
    required String productoId,
    required double cantidad,
    required double costoUnitario,
    String? proveedor,
    String? transaccionId,
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final insertados = await _client
        .from('compras')
        .insert({
          'negocio_id': negocioId,
          'producto_id': productoId,
          'cantidad': cantidad,
          'costo_unitario': costoUnitario,
          'proveedor': ?proveedor,
          'transaccion_id': ?transaccionId,
        })
        .select('id');

    return insertados.first['id'] as String;
  }

  @override
  Future<bool> actualizarProducto({
    required String nombre,
    double? precioVenta,
    double? precioCompra,
    double? stockMinimo,
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final result = await _client.rpc(
      'actualizar_producto',
      params: {
        'p_negocio_id': negocioId,
        'p_nombre': nombre,
        'p_precio_venta': ?precioVenta,
        'p_precio_compra': ?precioCompra,
        'p_stock_minimo': ?stockMinimo,
      },
    );

    return result == true;
  }

  @override
  Future<bool> actualizarProductoPorId({
    required String productoId,
    String? nuevoNombre,
    double? precioVenta,
    double? precioCompra,
    double? stockMinimo,
    double? stockMaximo,
    String? unidadMedida,
    String? categoriaProducto,
    String? codigoBarras,
    String? imagenUrl,
    String? proveedorId,
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    try {
      final res = await _client.rpc('actualizar_producto_por_id', params: {
        'p_negocio_id': negocioId,
        'p_producto_id': productoId,
        'p_nuevo_nombre': ?nuevoNombre,
        'p_precio_venta': ?precioVenta,
        'p_precio_compra': ?precioCompra,
        'p_stock_minimo': ?stockMinimo,
        'p_stock_maximo': ?stockMaximo,
        'p_unidad_medida': ?unidadMedida,
        'p_categoria_producto': ?categoriaProducto,
        'p_codigo_barras': ?codigoBarras,
        'p_imagen_url': ?imagenUrl,
        'p_proveedor_id': ?proveedorId,
      });
      if (res == true) return true;
    } catch (_) {}

    final data = <String, dynamic>{'activo': true};
    if (nuevoNombre != null && nuevoNombre.trim().isNotEmpty) {
      data['nombre'] = nuevoNombre.trim();
      data['nombre_normalizado'] = nuevoNombre.trim().toLowerCase();
    }
    if (precioVenta != null) data['precio_venta'] = precioVenta;
    if (precioCompra != null) data['precio_compra'] = precioCompra;
    if (stockMinimo != null) data['stock_minimo'] = stockMinimo;
    if (stockMaximo != null) data['stock_maximo'] = stockMaximo;
    if (unidadMedida != null) data['unidad_medida'] = unidadMedida;
    if (categoriaProducto != null) data['categoria_producto'] = categoriaProducto;
    if (codigoBarras != null) data['codigo_barras'] = codigoBarras;
    if (imagenUrl != null) data['imagen_url'] = imagenUrl;
    if (proveedorId != null) data['proveedor_id'] = proveedorId;

    final updated = await _client
        .from('productos')
        .update(data)
        .eq('id', productoId)
        .eq('negocio_id', negocioId)
        .select('id');
    return updated.isNotEmpty;
  }

  @override
  Future<bool> ajustarInventario({
    required String nombre,
    required double cantidadObjetivo,
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final result = await _client.rpc(
      'ajustar_inventario',
      params: {
        'p_negocio_id': negocioId,
        'p_nombre': nombre,
        'p_cantidad_objetivo': cantidadObjetivo,
      },
    );

    return result == true;
  }

  @override
  Future<bool> ajustarInventarioConMotivo({
    required String productoId,
    required double cantidadObjetivo,
    String motivo = 'Ajuste manual',
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    try {
      final res = await _client.rpc('ajustar_inventario_con_motivo', params: {
        'p_negocio_id': negocioId,
        'p_producto_id': productoId,
        'p_cantidad_objetivo': cantidadObjetivo,
        'p_motivo': motivo,
      });
      if (res == true) return true;
    } catch (_) {}

    final prod = await _client
        .from('productos')
        .select('nombre')
        .eq('id', productoId)
        .maybeSingle();
    if (prod != null) {
      return ajustarInventario(
        nombre: prod['nombre'].toString(),
        cantidadObjetivo: cantidadObjetivo,
      );
    }
    return false;
  }

  @override
  Future<List<Proveedor>> obtenerProveedores() async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    try {
      final rows = await _client
          .from('proveedores')
          .select('*')
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .order('nombre');

      return (rows as List)
          .map((e) => Proveedor.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Proveedor?> crearProveedor({
    required String nombre,
    String? contacto,
    String? telefono,
    String? direccion,
    String? diasVisita,
    String? notas,
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final rows = await _client
        .from('proveedores')
        .insert({
          'negocio_id': negocioId,
          'nombre': nombre.trim(),
          'contacto': ?contacto?.trim(),
          'telefono': ?telefono?.trim(),
          'direccion': ?direccion?.trim(),
          'dias_visita': ?diasVisita?.trim(),
          'notas': ?notas?.trim(),
          'activo': true,
        })
        .select('*');

    if (rows.isEmpty) return null;
    return Proveedor.fromJson(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<bool> actualizarProveedor(Proveedor proveedor) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final rows = await _client
        .from('proveedores')
        .update({
          'nombre': proveedor.nombre.trim(),
          'contacto': ?proveedor.contacto?.trim(),
          'telefono': ?proveedor.telefono?.trim(),
          'direccion': ?proveedor.direccion?.trim(),
          'dias_visita': ?proveedor.diasVisita?.trim(),
          'notas': ?proveedor.notas?.trim(),
          'activo': proveedor.activo,
          'actualizado_en': DateTime.now().toIso8601String(),
        })
        .eq('id', proveedor.id)
        .eq('negocio_id', negocioId)
        .select('id');

    return rows.isNotEmpty;
  }

  @override
  Future<bool> eliminarProveedor(String id) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    final rows = await _client
        .from('proveedores')
        .update({'activo': false})
        .eq('id', id)
        .eq('negocio_id', negocioId)
        .select('id');

    return rows.isNotEmpty;
  }

  @override
  Future<List<MovimientoKardex>> obtenerKardexProducto({
    required String productoId,
    int limite = 30,
  }) async {
    try {
      final rows = await _client.rpc(
        'obtener_kardex_producto',
        params: {'p_producto_id': productoId, 'p_limite': limite},
      );
      return _filasDe(rows).map(MovimientoKardex.fromJson).toList();
    } catch (_) {
      try {
        final rows = await _client
            .from('movimientos_inventario')
            .select('*')
            .eq('producto_id', productoId)
            .order('creado_en', ascending: false)
            .limit(limite);
        return (rows as List)
            .map((e) => MovimientoKardex.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  @override
  Future<String?> subirImagenProducto({
    required List<int> bytes,
    required String extension,
  }) async {
    try {
      await _asegurarSesion();
      final nombreArchivo =
          'prod_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.$extension';

      await _client.storage.from('productos').uploadBinary(
            nombreArchivo,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      return _client.storage.from('productos').getPublicUrl(nombreArchivo);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> registrarVentaPos({
    required List<ItemVentaPos> items,
    required String metodoPago,
    String? notas,
  }) async {
    if (items.isEmpty) return false;
    await _asegurarSesion();
    final negocioId = _negocioId!;

    String catId = '';
    try {
      catId = await buscarOCrearCategoriaNivel2(
        categoriaNivel1: 'Ingresos',
        categoriaNivel2: 'Ventas POS',
        tipo: 'ingreso',
      );
    } catch (e) {
      debugPrint('No se pudo resolver categoria nivel 2 Ventas POS: $e');
    }

    if (catId.isEmpty) {
      try {
        final defaultCat = await _client
            .from('categorias')
            .select('id')
            .eq('tipo', 'ingreso')
            .limit(1)
            .maybeSingle();
        catId = defaultCat?['id'] as String? ?? '';
      } catch (e) {
        debugPrint('Error buscando categoria ingreso por defecto: $e');
      }
    }

    if (catId.isEmpty) {
      try {
        final anyCat = await _client
            .from('categorias')
            .select('id')
            .limit(1)
            .maybeSingle();
        catId = anyCat?['id'] as String? ?? '';
      } catch (e) {
        debugPrint('Error buscando categoria alternativa: $e');
      }
    }

    if (catId.isEmpty) {
      throw PersistException(
        'No se encontró una categoría contable válida para registrar el ingreso.',
      );
    }

    for (final item in items) {
      String? prodId = item.producto.id;
      if (prodId == null || prodId.isEmpty) {
        try {
          prodId = await buscarOCrearProducto(
            nombre: item.producto.nombre,
            precioCompra: item.producto.costoPromedio ?? item.producto.precioCompra,
            precioVenta: item.producto.precioVenta,
          );
        } catch (e) {
          debugPrint('Error asegurando producto para venta POS: $e');
        }
      }

      final cantStr = item.cantidad % 1 == 0
          ? item.cantidad.toInt().toString()
          : item.cantidad.toStringAsFixed(2);

      final payload = <String, dynamic>{
        'negocio_id': negocioId,
        'categoria_id': catId,
        'monto': item.subtotal,
        'tipo': 'ingreso',
        'descripcion_original': 'Venta POS (${metodoPago.toUpperCase()}): ${item.producto.nombre} x$cantStr',
        'descripcion_normalizada': item.producto.nombre,
        'origen': 'manual',
        'confianza_clasificacion': 1.0,
        'confirmado_por_usuario': true,
        'cantidad': item.cantidad,
        'precio_unitario': item.precioUnitario,
        if (prodId != null && prodId.isNotEmpty) 'producto_id': prodId,
      };

      try {
        final payloadConMetodo = Map<String, dynamic>.from(payload);
        payloadConMetodo['metodo_pago'] = metodoPago;
        await _client.from('transacciones').insert(payloadConMetodo);
      } catch (e) {
        debugPrint('Insertando sin columna metodo_pago por fallback: $e');
        await _client.from('transacciones').insert(payload);
      }
    }

    return true;
  }

  @override
  Future<List<CuentaPorCobrar>> obtenerCuentasPorCobrar({String? estado}) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    try {
      var query = _client
          .from('cuentas_por_cobrar')
          .select('*')
          .eq('negocio_id', negocioId);

      if (estado != null && estado.isNotEmpty) {
        query = query.eq('estado', estado);
      }

      final rows = await query.order('creado_en', ascending: false);
      return (rows as List).map((r) => CuentaPorCobrar.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error al obtener cuentas_por_cobrar: $e');
      return [];
    }
  }

  @override
  Future<CuentaPorCobrar?> registrarFiado({
    required String clienteNombre,
    required double monto,
    String? descripcion,
    String? clienteTelefono,
    DateTime? fechaLimite,
    String? transaccionId,
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    try {
      final insertados = await _client.from('cuentas_por_cobrar').insert({
        'negocio_id': negocioId,
        'cliente_nombre': clienteNombre.trim(),
        'cliente_telefono': clienteTelefono?.trim(),
        'monto_total': monto,
        'saldo_pendiente': monto,
        'descripcion': descripcion?.trim(),
        'estado': 'pendiente',
        'fecha': DateTime.now().toIso8601String().substring(0, 10),
        if (fechaLimite != null)
          'fecha_limite': fechaLimite.toIso8601String().substring(0, 10),
        'transaccion_id': ?transaccionId,
      }).select('*');

      if (insertados.isNotEmpty) {
        return CuentaPorCobrar.fromMap(insertados.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error al registrar fiado: $e');
      return null;
    }
  }

  @override
  Future<bool> registrarAbonoFiado({
    required String cuentaId,
    required double monto,
    String metodoPago = 'efectivo',
    String? notas,
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    try {
      // 1. Registrar abono en tabla abonos_cuentas_cobrar
      try {
        await _client.from('abonos_cuentas_cobrar').insert({
          'cuenta_cobrar_id': cuentaId,
          'monto': monto,
          'metodo_pago': metodoPago,
          'fecha': DateTime.now().toIso8601String().substring(0, 10),
          'notas': notas,
        });
      } catch (eAbono) {
        debugPrint('Insert abonos_cuentas_cobrar: $eAbono');
      }

      // 2. Actualizar saldo_pendiente y estado
      final cuenta = await _client
          .from('cuentas_por_cobrar')
          .select('monto_total, saldo_pendiente, cliente_nombre')
          .eq('id', cuentaId)
          .maybeSingle();

      if (cuenta != null) {
        final saldoActual = (cuenta['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
        final nuevoSaldo = (saldoActual - monto) < 0 ? 0.0 : (saldoActual - monto);
        final nuevoEstado = nuevoSaldo <= 0 ? 'pagado' : 'parcial';

        await _client.from('cuentas_por_cobrar').update({
          'saldo_pendiente': nuevoSaldo,
          'estado': nuevoEstado,
          'actualizado_en': DateTime.now().toIso8601String(),
        }).eq('id', cuentaId);

        // 3. Registrar el ingreso del abono en transacciones para caja
        try {
          final catIngreso = await _client
              .from('categorias')
              .select('id')
              .eq('tipo', 'ingreso')
              .limit(1)
              .maybeSingle();
          final catId = catIngreso?['id'] as String? ?? '';

          if (catId.isNotEmpty) {
            await _client.from('transacciones').insert({
              'negocio_id': negocioId,
              'categoria_id': catId,
              'monto': monto,
              'tipo': 'ingreso',
              'descripcion_original': 'Abono fiado: ${cuenta['cliente_nombre'] ?? 'Cliente'}',
              'descripcion_normalizada': 'Abono de fiado',
              'origen': 'manual',
              'confianza_clasificacion': 1.0,
              'confirmado_por_usuario': true,
            });
          }
        } catch (eTr) {
          debugPrint('No se pudo insertar transacción de abono: $eTr');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error al registrar abono fiado: $e');
      return false;
    }
  }

  @override
  Future<List<SugerenciaPedidoProveedor>> obtenerSugerenciasPedidosProveedores() async {
    final prods = await inventario();
    final provs = await obtenerProveedores();

    if (prods.isEmpty || provs.isEmpty) return [];

    final ahora = DateTime.now();
    final nombresDias = {
      1: 'lunes',
      2: 'martes',
      3: 'miércoles',
      4: 'jueves',
      5: 'viernes',
      6: 'sábado',
      7: 'domingo',
    };
    final hoyNombre = nombresDias[ahora.weekday] ?? '';
    final mananaWeekday = ahora.weekday == 7 ? 1 : ahora.weekday + 1;
    final mananaNombre = nombresDias[mananaWeekday] ?? '';

    // Filtrar productos con stock bajo o agotado
    final productosBajos = prods.where((p) {
      final minStock = p.stockMinimo ?? 0.0;
      return p.estado == 'bajo' ||
          p.estado == 'agotado' ||
          (p.stockMinimo != null && p.existencias <= minStock);
    }).toList();

    final resultado = <SugerenciaPedidoProveedor>[];

    for (final prov in provs) {
      final prodsDelProveedor =
          productosBajos.where((p) => p.proveedorId == prov.id).toList();
      if (prodsDelProveedor.isEmpty) continue;

      final diasVisitaLower = (prov.diasVisita ?? '').toLowerCase();
      final esVisitaHoy = diasVisitaLower.contains(hoyNombre);
      final esVisitaManana = diasVisitaLower.contains(mananaNombre);

      final itemsSugeridos = <ItemSugerenciaProducto>[];
      var costoTotal = 0.0;

      for (final p in prodsDelProveedor) {
        final cantMinima = (p.stockMinimo != null && p.stockMinimo! > 0)
            ? p.stockMinimo!
            : 5.0;
        final cantSugerida = p.stockMaximo != null && p.stockMaximo! > p.existencias
            ? (p.stockMaximo! - p.existencias)
            : ((cantMinima * 2) - p.existencias);
        final cantFinal = cantSugerida > 0 ? cantSugerida : cantMinima;

        final costoUnit =
            p.precioCompra > 0 ? p.precioCompra : (p.costoPromedio ?? 0.0);
        final subtotal = double.parse((cantFinal * costoUnit).toStringAsFixed(2));
        costoTotal += subtotal;

        itemsSugeridos.add(ItemSugerenciaProducto(
          producto: p,
          existenciasActuales: p.existencias,
          stockMinimo: p.stockMinimo ?? 0.0,
          cantidadSugerida: cantFinal,
          costoUnitario: costoUnit,
          costoTotalEstimado: subtotal,
        ));
      }

      resultado.add(SugerenciaPedidoProveedor(
        proveedor: prov,
        productos: itemsSugeridos,
        costoTotalEstimado: double.parse(costoTotal.toStringAsFixed(2)),
        diaVisitaTexto: prov.diasVisita ?? 'Sin días especificados',
        esVisitaHoy: esVisitaHoy,
        esVisitaManana: esVisitaManana,
      ));
    }

    resultado.sort((a, b) {
      if (a.esVisitaHoy && !b.esVisitaHoy) return -1;
      if (!a.esVisitaHoy && b.esVisitaHoy) return 1;
      if (a.esVisitaManana && !b.esVisitaManana) return -1;
      if (!a.esVisitaManana && b.esVisitaManana) return 1;
      return b.costoTotalEstimado.compareTo(a.costoTotalEstimado);
    });

    return resultado;
  }

  @override
  Future<String?> registrarGastoManual({
    required double monto,
    required String categoriaNivel1,
    String? categoriaNivel2,
    required String descripcion,
    String? metodoPago,
  }) async {
    await _asegurarSesion();
    final negocioId = _negocioId!;

    String catId = '';
    if (categoriaNivel2 != null && categoriaNivel2.isNotEmpty) {
      try {
        catId = await buscarOCrearCategoriaNivel2(
          categoriaNivel1: categoriaNivel1,
          categoriaNivel2: categoriaNivel2,
          tipo: 'egreso',
        );
      } catch (_) {}
    }

    if (catId.isEmpty) {
      try {
        final cat = await _client
            .from('categorias')
            .select('id')
            .eq('nombre', categoriaNivel1)
            .limit(1)
            .maybeSingle();
        catId = cat?['id'] as String? ?? '';
      } catch (_) {}
    }

    if (catId.isEmpty) {
      try {
        final catEgreso = await _client
            .from('categorias')
            .select('id')
            .eq('tipo', 'egreso')
            .limit(1)
            .maybeSingle();
        catId = catEgreso?['id'] as String? ?? '';
      } catch (_) {}
    }

    if (catId.isEmpty) {
      throw PersistException('No se encontró categoría para el gasto');
    }

    final payload = <String, dynamic>{
      'negocio_id': negocioId,
      'categoria_id': catId,
      'monto': monto,
      'tipo': 'egreso',
      'descripcion_original': metodoPago != null
          ? 'Gasto ($metodoPago): $descripcion'
          : descripcion,
      'descripcion_normalizada': descripcion,
      'origen': 'manual',
      'confianza_clasificacion': 1.0,
      'confirmado_por_usuario': true,
    };

    try {
      final insertados =
          await _client.from('transacciones').insert(payload).select('id');
      return insertados.first['id'] as String;
    } catch (e) {
      debugPrint('Error registrando gasto manual: $e');
      return null;
    }
  }
}
