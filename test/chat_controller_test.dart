import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_ia/models/llm_response.dart';
import 'package:finanzas_ia/providers/chat_provider.dart';
import 'package:finanzas_ia/services/llm_service.dart';

class _FakeLlmService extends LlmService {
  _FakeLlmService(this.responses);

  final List<LlmResponse> responses;
  int calls = 0;

  @override
  Future<LlmResponse> classify({required String text}) async {
    if (responses.isEmpty || calls >= responses.length) {
      throw LlmException('fallo simulado del LLM');
    }
    final index = calls;
    calls++;
    return responses[index];
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

LlmResponse _conversacion() {
  return const LlmResponse(
    tipoRespuesta: TipoRespuesta.conversacion,
    mensajeParaUsuario: 'Hola, ¿en qué te ayudo?',
    datosTransaccion: null,
  );
}

void main() {
  test('mensaje transaccional muestra tarjeta pendiente y no burbuja', () async {
    final controller = ChatController(_FakeLlmService([_transaccion()]));

    await controller.sendMessage('vendí Q200 de fruta hoy');

    expect(controller.state.messages.length, 1);
    expect(controller.state.messages.first.isUser, isTrue);
    expect(controller.state.pendingTransaction, isNotNull);
    expect(controller.state.pendingTransaction!.datos.monto, 200);
    expect(controller.state.isSending, isFalse);
  });

  test('mensaje conversacional agrega burbuja de asistente', () async {
    final controller = ChatController(_FakeLlmService([_conversacion()]));

    await controller.sendMessage('hola buenos días');

    expect(controller.state.messages.length, 2);
    expect(controller.state.messages.last.isUser, isFalse);
    expect(controller.state.messages.last.text, 'Hola, ¿en qué te ayudo?');
    expect(controller.state.pendingTransaction, isNull);
    expect(controller.state.isSending, isFalse);
  });

  test('confirmar transacción limpia la tarjeta y agrega confirmación', () async {
    final controller = ChatController(_FakeLlmService([_transaccion()]));

    await controller.sendMessage('vendí Q200 de fruta hoy');
    controller.acceptPendingTransaction();

    expect(controller.state.pendingTransaction, isNull);
    expect(controller.state.messages.length, 2);
    expect(controller.state.messages.last.isUser, isFalse);
    expect(controller.state.messages.last.text, '✓ Registrado: Ingreso de Q200.00 en Ingresos › Venta de producto.');
    expect(controller.state.messages.last.tipoMovimiento, 'ingreso');
  });

  test('corregir transacción actualiza los datos de la tarjeta', () async {
    final controller = ChatController(_FakeLlmService([_transaccion()]));

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
    final controller = ChatController(_FakeLlmService([_transaccion()]));

    await controller.sendMessage('vendí Q200 de fruta hoy');
    controller.updatePendingTransaction(
      monto: 250,
      tipo: 'egreso',
      categoriaNivel1: 'Costos de venta',
      categoriaNivel2: 'Mercadería',
    );
    controller.acceptPendingTransaction();

    final feedback = controller.state.messages.last;
    expect(feedback.text, '✓ Registrado: Egreso de Q250.00 en Costos de venta › Mercadería.');
    expect(feedback.tipoMovimiento, 'egreso');
  });

  test('error del LLM produce burbuja de error sin tarjeta', () async {
    final controller = ChatController(_FakeLlmService([]));

    await controller.sendMessage('hola');

    expect(controller.state.pendingTransaction, isNull);
    expect(controller.state.messages.last.isUser, isFalse);
    expect(controller.state.messages.last.text, contains('error'));
  });
}
