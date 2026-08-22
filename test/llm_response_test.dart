import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_ia/models/llm_response.dart';

void main() {
  test('parsea una transacción completa', () {
    const json = '''
    {
      "tipo_respuesta": "transaccion",
      "mensaje_para_usuario": "Detecté una venta de Q200. ¿Confirmas?",
      "datos_transaccion": {
        "monto": 200,
        "tipo": "ingreso",
        "categoria_nivel1_sugerida": "Ingresos",
        "categoria_nivel2_sugerida": "Venta de producto",
        "confianza": 0.92
      }
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.tipoRespuesta, TipoRespuesta.transaccion);
    expect(response.mensajeParaUsuario, 'Detecté una venta de Q200. ¿Confirmas?');
    expect(response.datosTransaccion, isNotNull);
    expect(response.datosTransaccion!.monto, 200);
    expect(response.datosTransaccion!.tipo, 'ingreso');
    expect(response.datosTransaccion!.categoriaNivel1Sugerida, 'Ingresos');
    expect(response.datosTransaccion!.categoriaNivel2Sugerida, 'Venta de producto');
    expect(response.datosTransaccion!.confianza, 0.92);
  });

  test('parsea conversación con datos_transaccion null', () {
    const json = '''
    {
      "tipo_respuesta": "conversacion",
      "mensaje_para_usuario": "Hola, ¿en qué te ayudo?",
      "datos_transaccion": null
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.tipoRespuesta, TipoRespuesta.conversacion);
    expect(response.datosTransaccion, isNull);
  });

  test('parsea consulta_reporte', () {
    const json = '''
    {
      "tipo_respuesta": "consulta_reporte",
      "mensaje_para_usuario": "Aún no disponible.",
      "datos_transaccion": null
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.tipoRespuesta, TipoRespuesta.consultaReporte);
    expect(response.datosTransaccion, isNull);
    expect(response.datosConsulta, isNull);
  });

  test('parsea datos_consulta en consulta_reporte', () {
    const json = '''
    {
      "tipo_respuesta": "consulta_reporte",
      "mensaje_para_usuario": "Te muestro tus egresos del mes.",
      "datos_transaccion": null,
      "datos_consulta": {
        "tipo_reporte": "egresos",
        "periodo": "mes_actual",
        "categoria_nivel1": null
      }
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.tipoRespuesta, TipoRespuesta.consultaReporte);
    expect(response.datosConsulta, isNotNull);
    expect(response.datosConsulta!.tipoReporte, 'egresos');
    expect(response.datosConsulta!.periodo, 'mes_actual');
    expect(response.datosConsulta!.categoriaNivel1, isNull);
  });

  test('monto numérico como string se convierte a double', () {
    const json = '''
    {
      "tipo_respuesta": "transaccion",
      "mensaje_para_usuario": "",
      "datos_transaccion": {
        "monto": "150.50",
        "tipo": "egreso",
        "categoria_nivel1_sugerida": "Gastos operativos",
        "categoria_nivel2_sugerida": "Renta",
        "confianza": 0.8
      }
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.datosTransaccion!.monto, 150.50);
  });
}
