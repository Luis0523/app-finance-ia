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
    expect(
      response.mensajeParaUsuario,
      'Detecté una venta de Q200. ¿Confirmas?',
    );
    expect(response.datosTransaccion, isNotNull);
    expect(response.datosTransaccion!.monto, 200);
    expect(response.datosTransaccion!.tipo, 'ingreso');
    expect(response.datosTransaccion!.categoriaNivel1Sugerida, 'Ingresos');
    expect(
      response.datosTransaccion!.categoriaNivel2Sugerida,
      'Venta de producto',
    );
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

  test('parsea tipo_consulta y tipo en datos_consulta', () {
    const json = '''
    {
      "tipo_respuesta": "consulta_reporte",
      "mensaje_para_usuario": "",
      "datos_transaccion": null,
      "datos_consulta": {
        "tipo_consulta": "ultima_transaccion",
        "tipo": "ingreso"
      }
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.datosConsulta!.tipoConsulta, 'ultima_transaccion');
    expect(response.datosConsulta!.tipo, 'ingreso');
  });

  test('parsea el monto planeado en consultas de viabilidad', () {
    const json = '''
    {
      "tipo_respuesta": "consulta_reporte",
      "mensaje_para_usuario": "",
      "datos_transaccion": null,
      "datos_consulta": {
        "tipo_consulta": "viabilidad",
        "monto": 500.5
      }
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.datosConsulta!.tipoConsulta, 'viabilidad');
    expect(response.datosConsulta!.monto, 500.5);
  });

  test('parsea tipo_consulta ganancias', () {
    const json = '''
    {
      "tipo_respuesta": "consulta_reporte",
      "mensaje_para_usuario": "",
      "datos_transaccion": null,
      "datos_consulta": {
        "tipo_consulta": "ganancias"
      }
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.datosConsulta!.tipoConsulta, 'ganancias');
  });

  test('parsea actualizar_producto y ajustar_inventario', () {
    const json = '''
    {
      "tipo_respuesta": "consulta_reporte",
      "mensaje_para_usuario": "",
      "datos_transaccion": null,
      "datos_consulta": {
        "tipo_consulta": "actualizar_producto",
        "producto": "Gaseosas",
        "precio_venta": 5,
        "precio_compra": 3,
        "stock_minimo": 10
      }
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.datosConsulta!.tipoConsulta, 'actualizar_producto');
    expect(response.datosConsulta!.producto, 'Gaseosas');
    expect(response.datosConsulta!.precioVenta, 5);
    expect(response.datosConsulta!.precioCompra, 3);
    expect(response.datosConsulta!.stockMinimo, 10);
  });

  test('parsea cantidad objetivo en ajustar_inventario', () {
    const json = '''
    {
      "tipo_respuesta": "consulta_reporte",
      "mensaje_para_usuario": "",
      "datos_transaccion": null,
      "datos_consulta": {
        "tipo_consulta": "ajustar_inventario",
        "producto": "Gaseosas",
        "cantidad_objetivo": 50
      }
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.datosConsulta!.tipoConsulta, 'ajustar_inventario');
    expect(response.datosConsulta!.producto, 'Gaseosas');
    expect(response.datosConsulta!.cantidadObjetivo, 50);
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

  test('parsea cantidad y precio unitario en la transacción', () {
    const json = '''
    {
      "tipo_respuesta": "transaccion",
      "mensaje_para_usuario": "",
      "datos_transaccion": {
        "monto": 3400,
        "tipo": "egreso",
        "categoria_nivel1_sugerida": "Costos de venta",
        "categoria_nivel2_sugerida": "Materia prima / Insumos",
        "confianza": 0.9,
        "descripcion_normalizada": "Compra de bananos",
        "cantidad": 340,
        "precio_unitario": 10,
        "producto_sugerido": "Bananos",
        "accion_inventario": "compra",
        "confianza_inventario": 0.9
      }
    }
    ''';

    final response = LlmResponse.fromJson(json);

    expect(response.datosTransaccion!.cantidad, 340);
    expect(response.datosTransaccion!.precioUnitario, 10);
    expect(response.datosTransaccion!.monto, 3400);
    expect(
      response.datosTransaccion!.descripcionNormalizada,
      'Compra de bananos',
    );
    expect(response.datosTransaccion!.productoSugerido, 'Bananos');
    expect(response.datosTransaccion!.accionInventario, 'compra');
    expect(response.datosTransaccion!.confianzaInventario, 0.9);
    expect(response.datosTransaccion!.tieneDesglose, isTrue);
  });
}
