import 'dart:convert';

enum TipoRespuesta {
  transaccion,
  conversacion,
  consultaReporte;

  static TipoRespuesta fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'transaccion':
        return TipoRespuesta.transaccion;
      case 'consulta_reporte':
        return TipoRespuesta.consultaReporte;
      case 'conversacion':
      default:
        return TipoRespuesta.conversacion;
    }
  }
}

class DatosTransaccion {
  const DatosTransaccion({
    required this.monto,
    required this.tipo,
    required this.categoriaNivel1Sugerida,
    required this.categoriaNivel2Sugerida,
    required this.confianza,
    this.descripcionNormalizada,
    this.cantidad,
    this.precioUnitario,
  });

  final double monto;
  final String tipo;
  final String categoriaNivel1Sugerida;
  final String categoriaNivel2Sugerida;
  final double confianza;
  final String? descripcionNormalizada;

  /// Número de unidades (opcional).
  final double? cantidad;

  /// Costo/precio por unidad en quetzales (opcional).
  final double? precioUnitario;

  bool get tieneDesglose => cantidad != null && precioUnitario != null;

  factory DatosTransaccion.fromMap(Map<String, dynamic> map) {
    return DatosTransaccion(
      monto: _asDouble(map['monto']),
      tipo: map['tipo']?.toString() ?? '',
      categoriaNivel1Sugerida: map['categoria_nivel1_sugerida']?.toString() ?? '',
      categoriaNivel2Sugerida:
          map['categoria_nivel2_sugerida']?.toString() ?? '',
      confianza: _asDouble(map['confianza']),
      descripcionNormalizada: map['descripcion_normalizada']?.toString(),
      cantidad: _asDoubleOrNull(map['cantidad']),
      precioUnitario: _asDoubleOrNull(map['precio_unitario']),
    );
  }

  DatosTransaccion copyWith({
    double? monto,
    String? tipo,
    String? categoriaNivel1Sugerida,
    String? categoriaNivel2Sugerida,
    double? confianza,
    String? descripcionNormalizada,
    double? cantidad,
    double? precioUnitario,
  }) {
    return DatosTransaccion(
      monto: monto ?? this.monto,
      tipo: tipo ?? this.tipo,
      categoriaNivel1Sugerida:
          categoriaNivel1Sugerida ?? this.categoriaNivel1Sugerida,
      categoriaNivel2Sugerida:
          categoriaNivel2Sugerida ?? this.categoriaNivel2Sugerida,
      confianza: confianza ?? this.confianza,
      descripcionNormalizada:
          descripcionNormalizada ?? this.descripcionNormalizada,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed ?? 0;
  }

  static double? _asDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class DatosConsulta {
  const DatosConsulta({
    this.tipoConsulta,
    this.tipoReporte,
    this.tipo,
    this.periodo,
    this.categoriaNivel1,
    this.monto,
  });

  /// 'totales' | 'ultima_transaccion' | 'analisis' | 'listado' |
  /// 'flujo_caja' | 'viabilidad' | 'inventario' | null
  final String? tipoConsulta;

  /// 'ingresos' | 'egresos' | 'ambos' | null
  final String? tipoReporte;

  /// Filtro de tipo: 'ingreso' | 'egreso' | null
  final String? tipo;

  /// 'hoy' | 'mes_actual' | 'mes_pasado' | null
  final String? periodo;

  /// Una de las 8 categorías de nivel 1 o null.
  final String? categoriaNivel1;

  /// Monto planeado (para consultas de viabilidad de compra).
  final double? monto;

  factory DatosConsulta.fromMap(Map<String, dynamic> map) => DatosConsulta(
        tipoConsulta: map['tipo_consulta']?.toString(),
        tipoReporte: map['tipo_reporte']?.toString(),
        tipo: map['tipo']?.toString(),
        periodo: map['periodo']?.toString(),
        categoriaNivel1: map['categoria_nivel1']?.toString(),
        monto: _asDouble(map['monto']),
      );

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class LlmResponse {
  const LlmResponse({
    required this.tipoRespuesta,
    required this.mensajeParaUsuario,
    required this.datosTransaccion,
    this.datosConsulta,
  });

  final TipoRespuesta tipoRespuesta;
  final String mensajeParaUsuario;
  final DatosTransaccion? datosTransaccion;
  final DatosConsulta? datosConsulta;

  factory LlmResponse.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return LlmResponse(
      tipoRespuesta: TipoRespuesta.fromString(map['tipo_respuesta']?.toString()),
      mensajeParaUsuario: map['mensaje_para_usuario']?.toString() ?? '',
      datosTransaccion: map['datos_transaccion'] == null
          ? null
          : DatosTransaccion.fromMap(
              map['datos_transaccion'] as Map<String, dynamic>,
            ),
      datosConsulta: map['datos_consulta'] == null
          ? null
          : DatosConsulta.fromMap(
              map['datos_consulta'] as Map<String, dynamic>,
            ),
    );
  }
}
