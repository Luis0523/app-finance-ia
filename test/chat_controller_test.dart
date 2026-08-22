import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_ia/models/chat_message.dart';
import 'package:finanzas_ia/models/llm_response.dart';
import 'package:finanzas_ia/providers/chat_provider.dart';
import 'package:finanzas_ia/services/llm_service.dart';

import 'fakes/fake_repository.dart';

class _FakeLlmService extends LlmService {
  _FakeLlmService(this.responses);

  final List<LlmResponse> responses;
  int calls = 0;
  int analisisLlamadas = 0;
  String? ultimoResumen;
  List<List<ChatMessage>> historiales = [];

  @override
  Future<LlmResponse> classify({
    required String text,
    List<ChatMessage> historial = const [],
  }) async {
    historiales.add(historial);
    if (responses.isEmpty || calls >= responses.length) {
      throw LlmException('fallo simulado del LLM');
    }
    final index = calls;
    calls++;
    return responses[index];
  }

  @override
  Future<String> analizar({required String resumen, String? prompt}) async {
    analisisLlamadas++;
    ultimoResumen = resumen;
    return 'Vas bien: balance positivo y ventas por encima de tus gastos.';
  }
}

LlmResponse _transaccion() {
  return LlmResponse(
    tipoRespuesta: TipoRespuesta.transaccion,
    mensajeParaUsuario: 'Detecté una venta de Q200. ¿Confirmas?',
    datosTransaccion: const DatosTransaccion(
      monto: 200,
      tipo: 'ingreso',
      categoriaNivel1Sugerida: 'Ingresos',
      categoriaNivel2Sugerida: 'Venta de producto',
      confianza: 0.92,
    ),
  );
}

LlmResponse _transaccionDe300() {
  return LlmResponse(
    tipoRespuesta: TipoRespuesta.transaccion,
    mensajeParaUsuario: 'Detecté una venta de Q300. ¿Confirmas?',
    datosTransaccion: const DatosTransaccion(
      monto: 300,
      tipo: 'ingreso',
      categoriaNivel1Sugerida: 'Ingresos',
      categoriaNivel2Sugerida: 'Venta de producto',
      confianza: 0.9,
    ),
  );
}

LlmResponse _transaccionConDesglose() {
  return LlmResponse(
    tipoRespuesta: TipoRespuesta.transaccion,
    mensajeParaUsuario: 'Compré 340 × Q10.00 = Q3400.00, ¿correcto?',
    datosTransaccion: const DatosTransaccion(
      monto: 0,
      tipo: 'egreso',
      categoriaNivel1Sugerida: 'Costos de venta',
      categoriaNivel2Sugerida: 'Materia prima / Insumos',
      confianza: 0.9,
      cantidad: 340,
      precioUnitario: 10,
    ),
  );
}

LlmResponse _transaccionSinMonto() {
  return LlmResponse(
    tipoRespuesta: TipoRespuesta.transaccion,
    mensajeParaUsuario: 'Registré la compra.',
    datosTransaccion: const DatosTransaccion(
      monto: 0,
      tipo: 'egreso',
      categoriaNivel1Sugerida: 'Costos de venta',
      categoriaNivel2Sugerida: 'Materia prima',
      confianza: 0.5,
    ),
  );
}

LlmResponse _conversacion() {
  return const LlmResponse(
    tipoRespuesta: TipoRespuesta.conversacion,
    mensajeParaUsuario: 'Hola, ¿en qué te ayudo?',
    datosTransaccion: null,
  );
}

LlmResponse _consultaReporte() {
  return const LlmResponse(
    tipoRespuesta: TipoRespuesta.consultaReporte,
    mensajeParaUsuario: 'Te muestro tus totales del mes.',
    datosTransaccion: null,
    datosConsulta: DatosConsulta(tipoReporte: 'ambos', periodo: 'mes_actual'),
  );
}

LlmResponse _consultaUltima() {
  return const LlmResponse(
    tipoRespuesta: TipoRespuesta.consultaReporte,
    mensajeParaUsuario: 'Aquí está tu último movimiento.',
    datosTransaccion: null,
    datosConsulta: DatosConsulta(
      tipoConsulta: 'ultima_transaccion',
      tipo: 'egreso',
    ),
  );
}

LlmResponse _consultaAnalisis() {
  return const LlmResponse(
    tipoRespuesta: TipoRespuesta.consultaReporte,
    mensajeParaUsuario: 'Aquí va mi análisis.',
    datosTransaccion: null,
    datosConsulta: DatosConsulta(tipoConsulta: 'analisis'),
  );
}

LlmResponse _consultaListado() {
  return const LlmResponse(
    tipoRespuesta: TipoRespuesta.consultaReporte,
    mensajeParaUsuario: 'Aquí está el detalle.',
    datosTransaccion: null,
    datosConsulta: DatosConsulta(
      tipoConsulta: 'listado',
      tipo: 'egreso',
    ),
  );
}

LlmResponse _consultaFlujo() {
  return const LlmResponse(
    tipoRespuesta: TipoRespuesta.consultaReporte,
    mensajeParaUsuario: 'Tu flujo de caja.',
    datosTransaccion: null,
    datosConsulta: DatosConsulta(tipoConsulta: 'flujo_caja'),
  );
}

LlmResponse _consultaInventario() {
  return const LlmResponse(
    tipoRespuesta: TipoRespuesta.consultaReporte,
    mensajeParaUsuario: 'Tu inventario.',
    datosTransaccion: null,
    datosConsulta: DatosConsulta(tipoConsulta: 'inventario'),
  );
}

LlmResponse _consultaViabilidad() {
  return const LlmResponse(
    tipoRespuesta: TipoRespuesta.consultaReporte,
    mensajeParaUsuario: 'Analizo la compra.',
    datosTransaccion: null,
    datosConsulta: DatosConsulta(
      tipoConsulta: 'viabilidad',
      monto: 500,
    ),
  );
}

void main() {
  test('mensaje transaccional muestra tarjeta pendiente y no burbuja', () async {
    final controller = ChatController(_FakeLlmService([_transaccion()]), FakeRepository());

    await controller.sendMessage('vendí Q200 de fruta hoy');

    expect(controller.state.messages.length, 1);
    expect(controller.state.messages.first.isUser, isTrue);
    expect(controller.state.pendingTransaction, isNotNull);
    expect(controller.state.pendingTransaction!.datos.monto, 200);
    expect(controller.state.pendingTransaction!.origen, 'texto');
    expect(controller.state.isSending, isFalse);
  });

  test('mensaje transaccional registra la conversación al enviar', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([_transaccion()]), repo);

    await controller.sendMessage('vendí Q200 de fruta hoy');

    expect(repo.conversaciones, 1);
    expect(controller.state.pendingTransaction!.conversacionId, repo.lastConversacionId);
  });

  test('mensaje conversacional agrega burbuja de asistente y log de conversación', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([_conversacion()]), repo);

    await controller.sendMessage('hola buenos días');

    expect(controller.state.messages.length, 2);
    expect(controller.state.messages.last.isUser, isFalse);
    expect(controller.state.messages.last.text, 'Hola, ¿en qué te ayudo?');
    expect(controller.state.pendingTransaction, isNull);
    expect(controller.state.isSending, isFalse);
    expect(repo.conversaciones, 1);
  });

  test('confirmar transacción persiste y agrega confirmación', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([_transaccion()]), repo);

    await controller.sendMessage('vendí Q200 de fruta hoy');
    await controller.acceptPendingTransaction();

    expect(controller.state.pendingTransaction, isNull);
    expect(repo.transacciones, 1);
    expect(repo.conversacionesActualizadas, 1);
    expect(repo.lastTransaccionId, isNotNull);
    expect(controller.state.messages.length, 2);
    expect(controller.state.messages.last.isUser, isFalse);
    expect(
      controller.state.messages.last.text,
      '✓ Registrado: Ingreso de Q200.00 en Ingresos › Venta de producto.',
    );
    expect(controller.state.messages.last.tipoMovimiento, 'ingreso');
  });

  test('corregir transacción actualiza los datos de la tarjeta', () async {
    final controller = ChatController(_FakeLlmService([_transaccion()]), FakeRepository());

    await controller.sendMessage('vendí Q200 de fruta hoy');
    controller.updatePendingTransaction(
      monto: 250,
      tipo: 'egreso',
      categoriaNivel1: 'Costos de venta',
      categoriaNivel2: 'Mercadería',
    );

    final datos = controller.state.pendingTransaction!.datos;
    expect(datos.monto, 250);
    expect(datos.tipo, 'egreso');
    expect(datos.categoriaNivel1Sugerida, 'Costos de venta');
    expect(datos.categoriaNivel2Sugerida, 'Mercadería');
  });

  test('corregir y confirmar usa los datos corregidos en el feedback', () async {
    final controller = ChatController(_FakeLlmService([_transaccion()]), FakeRepository());

    await controller.sendMessage('vendí Q200 de fruta hoy');
    controller.updatePendingTransaction(
      monto: 250,
      tipo: 'egreso',
      categoriaNivel1: 'Costos de venta',
      categoriaNivel2: 'Mercadería',
    );
    await controller.acceptPendingTransaction();

    final feedback = controller.state.messages.last;
    expect(feedback.text, '✓ Registrado: Egreso de Q250.00 en Costos de venta › Mercadería.');
    expect(feedback.tipoMovimiento, 'egreso');
  });

  test('origen voz se conserva en la tarjeta', () async {
    final controller = ChatController(_FakeLlmService([_transaccion()]), FakeRepository());

    controller.setInputFromSpeech('vendí Q200 de fruta hoy');
    await controller.sendMessage('vendí Q200 de fruta hoy');

    expect(controller.state.pendingTransaction!.origen, 'voz');
  });

  test('error del LLM produce burbuja de error sin tarjeta', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([]), repo);

    await controller.sendMessage('hola');

    expect(controller.state.pendingTransaction, isNull);
    expect(controller.state.messages.last.isUser, isFalse);
    expect(controller.state.messages.last.text, contains('error'));
    expect(repo.conversaciones, 0);
  });

  test('error de persistencia restaura la tarjeta', () async {
    final repo = FakeRepository()..failOnPersist = true;
    final controller = ChatController(_FakeLlmService([_transaccion()]), repo);

    await controller.sendMessage('vendí Q200 de fruta hoy');
    await controller.acceptPendingTransaction();

    expect(controller.state.pendingTransaction, isNotNull);
    expect(controller.state.isSaving, isFalse);
    expect(controller.state.messages.last.text, contains('No se pudo guardar'));
  });

  test('consulta de reporte agrega mensaje con totales del mes', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([_consultaReporte()]), repo);

    await controller.sendMessage('¿cuánto gasté este mes?');

    final message = controller.state.messages.last;
    expect(message.isUser, isFalse);
    expect(message.reporte, isNotNull);
    expect(message.reporte!.ingresos, 500);
    expect(message.reporte!.egresos, 300);
    expect(message.reporte!.balance, 200);
    expect(controller.state.pendingTransaction, isNull);
    expect(repo.totalesConsultas, 1);
    expect(repo.conversaciones, 1);
  });

  test('envía el historial previo como contexto al LLM', () async {
    final llm = _FakeLlmService([_conversacion(), _transaccion()]);
    final controller = ChatController(llm, FakeRepository());

    await controller.sendMessage('hola');
    await controller.sendMessage('a eso me refiero');

    // Primer mensaje: sin historial.
    expect(llm.historiales[0], isEmpty);

    // Segundo mensaje: el historial incluye el primer par (usuario + asistente).
    final segundo = llm.historiales[1];
    expect(segundo.length, 2);
    expect(segundo[0].isUser, isTrue);
    expect(segundo[0].text, 'hola');
    expect(segundo[1].isUser, isFalse);
    expect(segundo[1].text, 'Hola, ¿en qué te ayudo?');
  });

  test('un Error (no Exception) del LLM no deja atascado isSending', () async {
    final repo = FakeRepository();
    final controller = ChatController(_LlmmConError(), repo);

    await controller.sendMessage('hola');

    expect(controller.state.isSending, isFalse);
    expect(controller.state.pendingTransaction, isNull);
    expect(controller.state.messages.last.text, contains('error'));
  });

  test('tras guardar, la siguiente tarjeta no queda en isSaving', () async {
    final repo = FakeRepository();
    final llm = _FakeLlmService([_transaccion(), _transaccionDe300()]);
    final controller = ChatController(llm, repo);

    await controller.sendMessage('vendí Q200 de fruta hoy');
    await controller.acceptPendingTransaction();
    expect(controller.state.isSaving, isFalse);

    await controller.sendMessage('vendí Q300 de tomate');
    expect(controller.state.pendingTransaction, isNotNull);
    expect(controller.state.isSaving, isFalse);
    expect(controller.state.pendingTransaction!.datos.monto, 300);
  });

  test('un Error al persistir restaura la tarjeta sin atascar isSaving', () async {
    final repo = FakeRepository()..errorEnInsertar = StateError('boom');
    final controller = ChatController(_FakeLlmService([_transaccion()]), repo);

    await controller.sendMessage('vendí Q200 de fruta hoy');
    await controller.acceptPendingTransaction();

    expect(controller.state.pendingTransaction, isNotNull);
    expect(controller.state.isSaving, isFalse);
    expect(controller.state.messages.last.text, contains('No se pudo guardar'));
  });

  test('consulta de última transacción muestra el último egreso', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([_consultaUltima()]), repo);

    await controller.sendMessage('¿cuál fue mi último egreso?');

    final message = controller.state.messages.last;
    expect(message.isUser, isFalse);
    expect(message.tipoMovimiento, 'egreso');
    expect(message.text, contains('último egreso: Q150.00'));
    expect(message.text, contains('Servicios públicos'));
    expect(repo.ultimaConsultas, 1);
    expect(controller.state.pendingTransaction, isNull);
  });

  test('consulta de análisis usa el resumen agregado y responde análisis', () async {
    final repo = FakeRepository();
    final llm = _FakeLlmService([_consultaAnalisis()]);
    final controller = ChatController(llm, repo);

    await controller.sendMessage('¿qué tal ves mi balance?');

    final message = controller.state.messages.last;
    expect(message.isUser, isFalse);
    expect(message.text, contains('balance positivo'));
    expect(repo.resumenConsultas, 1);
    expect(llm.analisisLlamadas, 1);
    expect(llm.ultimoResumen, contains('Ingresos: Q500.00'));
    expect(llm.ultimoResumen, contains('Desglose por categoría'));
    expect(llm.ultimoResumen, contains('Venta de producto'));
  });

  test('listado de egresos devuelve una tabla filtrada por tipo', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([_consultaListado()]), repo);

    await controller.sendMessage('haz la lista de mis egresos');

    final message = controller.state.messages.last;
    expect(message.tabla, isNotNull);
    expect(message.tabla!.titulo, 'Mis egresos');
    expect(
      message.tabla!.headers,
      ['Fecha', 'Categoría', 'Descripción', 'Cant.', 'C. unit.', 'Total'],
    );
    expect(message.tabla!.rows.length, 1);
    expect(message.tabla!.rows.first.length, 6);
    expect(repo.ultimoTipoListado, 'egreso');
  });

  test('flujo de caja devuelve una tabla por día', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([_consultaFlujo()]), repo);

    await controller.sendMessage('¿cómo va mi flujo de caja?');

    final message = controller.state.messages.last;
    expect(message.tabla, isNotNull);
    expect(message.tabla!.titulo, 'Flujo de caja del mes');
    expect(repo.flujoConsultas, 1);
  });

  test('inventario devuelve tabla con productos y valor', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([_consultaInventario()]), repo);

    await controller.sendMessage('¿qué tengo en inventario?');

    final message = controller.state.messages.last;
    expect(message.tabla, isNotNull);
    expect(message.tabla!.titulo, contains('Inventario'));
    expect(message.text, contains('Q800.00'));
    expect(repo.inventarioConsultas, 1);
  });

  test('viabilidad de compra usa balance e inventario y responde análisis', () async {
    final repo = FakeRepository();
    final llm = _FakeLlmService([_consultaViabilidad()]);
    final controller = ChatController(llm, repo);

    await controller.sendMessage('quiero comprar mercadería por Q500, ¿es viable?');

    final message = controller.state.messages.last;
    expect(message.text, contains('balance positivo'));
    expect(llm.ultimoResumen, contains('Plan de compra: Q500.00'));
    expect(llm.ultimoResumen, contains('Balance: Q200.00'));
    expect(llm.ultimoResumen, contains('Valor total del inventario'));
    expect(repo.resumenConsultas, 1);
    expect(repo.inventarioConsultas, 1);
  });

  test('viabilidad sin monto pide el monto', () async {
    final repo = FakeRepository();
    final controller = ChatController(
      _FakeLlmService([
        const LlmResponse(
          tipoRespuesta: TipoRespuesta.consultaReporte,
          mensajeParaUsuario: '',
          datosTransaccion: null,
          datosConsulta: DatosConsulta(tipoConsulta: 'viabilidad'),
        ),
      ]),
      repo,
    );

    await controller.sendMessage('¿es viable comprar?');

    expect(controller.state.messages.last.text, contains('¿De cuánto'));
  });

  test('calcula el monto total a partir de cantidad × precio unitario', () async {
    final controller = ChatController(_FakeLlmService([_transaccionConDesglose()]), FakeRepository());

    await controller.sendMessage('compré 340 cosas a 10 quetzales cada una');

    final datos = controller.state.pendingTransaction!.datos;
    expect(datos.monto, 3400);
    expect(datos.cantidad, 340);
    expect(datos.precioUnitario, 10);
  });

  test('transacción sin monto pide el monto de forma conversacional', () async {
    final controller = ChatController(_FakeLlmService([_transaccionSinMonto()]), FakeRepository());

    await controller.sendMessage('compré algo pero no sé cuánto');

    expect(controller.state.pendingTransaction, isNull);
    expect(controller.state.messages.last.text, contains('¿De cuánto'));
  });

  test('feedback de confirmación incluye el desglose', () async {
    final repo = FakeRepository();
    final controller = ChatController(_FakeLlmService([_transaccionConDesglose()]), repo);

    await controller.sendMessage('compré 340 cosas a 10 quetzales cada una');
    await controller.acceptPendingTransaction();

    final feedback = controller.state.messages.last;
    expect(feedback.text, contains('340 × Q10.00'));
    expect(feedback.text, contains('Q3400.00'));
  });
}

class _LlmmConError extends LlmService {
  @override
  Future<LlmResponse> classify({
    required String text,
    List<ChatMessage> historial = const [],
  }) async {
    throw StateError('boom del LLM');
  }
}
