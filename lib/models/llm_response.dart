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
  });

  final double monto;
  final String tipo;
  final String categoriaNivel1Sugerida;
  final String categoriaNivel2Sugerida;
  final double confianza;

  factory DatosTransaccion.fromMap(Map<String, dynamic> map) {
    return DatosTransaccion(
      monto: _asDouble(map['monto']),
      tipo: map['tipo']?.toString() ?? '',
      categoriaNivel1Sugerida: map['categoria_nivel1_sugerida']?.toString() ?? '',
      categoriaNivel2Sugerida:
          map['categoria_nivel2_sugerida']?.toString() ?? '',
      confianza: _asDouble(map['confianza']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed ?? 0;
  }
}

class DatosConsulta {
  const DatosConsulta({
    this.tipoConsulta,
    this.tipoReporte,
    this.tipo,
    this.periodo,
    this.categoriaNivel1,
  });

  /// 'totales' | 'ultima_transaccion' | 'analisis' | null
  final String? tipoConsulta;

  /// 'ingresos' | 'egresos' | 'ambos' | null
  final String? tipoReporte;

  /// Filtro de tipo: 'ingreso' | 'egreso' | null
  final String? tipo;

  /// 'hoy' | 'mes_actual' | 'mes_pasado' | null
  final String? periodo;

  /// Una de las 8 categorías de nivel 1 o null.
  final String? categoriaNivel1;

  factory DatosConsulta.fromMap(Map<String, dynamic> map) => DatosConsulta(
        tipoConsulta: map['tipo_consulta']?.toString(),
        tipoReporte: map['tipo_reporte']?.toString(),
        tipo: map['tipo']?.toString(),
        periodo: map['periodo']?.toString(),
        categoriaNivel1: map['categoria_nivel1']?.toString(),
      );
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
