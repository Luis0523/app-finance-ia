import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_ia/models/llm_response.dart';
import 'package:finanzas_ia/services/llm_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respuestas);

  final List<Map<String, dynamic>> respuestas;
  int llamadas = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index =
        llamadas < respuestas.length ? llamadas : respuestas.length - 1;
    llamadas++;
    return ResponseBody.fromString(
      jsonEncode(respuestas[index]),
      200,
      headers: {'content-type': ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _respuesta(String content) => {
      'choices': [
        {'message': {'content': content}},
      ],
    };

Map<String, dynamic> _respuestaToolCall(String arguments) => {
      'choices': [
        {
          'message': {
            'tool_calls': [
              {
                'function': {'arguments': arguments},
              },
            ],
          },
        },
      ],
    };

const _jsonValido =
    '{"tipo_respuesta": "conversacion", "mensaje_para_usuario": "Hola", '
    '"datos_transaccion": null, "datos_consulta": null}';

void main() {
  test('reintenta cuando el LLM devuelve contenido vacío', () async {
    final adapter = _FakeAdapter([_respuesta(''), _respuesta(_jsonValido)]);
    final service = LlmService(
      dio: Dio()..httpClientAdapter = adapter,
      apiKey: 'sk-test',
    );

    final respuesta = await service.classify(text: 'hola');

    expect(respuesta.tipoRespuesta, TipoRespuesta.conversacion);
    expect(adapter.llamadas, 2);
  });

  test('lanza LlmException si los reintentos también fallan', () async {
    final adapter = _FakeAdapter([_respuesta(''), _respuesta(''), _respuesta('')]);
    final service = LlmService(
      dio: Dio()..httpClientAdapter = adapter,
      apiKey: 'sk-test',
    );

    await expectLater(
      service.classify(text: 'hola'),
      throwsA(isA<LlmException>()),
    );
    expect(adapter.llamadas, 3);
  });

  test('lanza LlmException si falta la API key', () async {
    final service = LlmService(apiKey: 'tu_key_placeholder');

    await expectLater(
      service.classify(text: 'hola'),
      throwsA(isA<LlmException>()),
    );
  });

  test('parsea la respuesta vía tool_calls (function calling)', () async {
    final adapter = _FakeAdapter([
      _respuestaToolCall(_jsonValido),
    ]);
    final service = LlmService(
      dio: Dio()..httpClientAdapter = adapter,
      apiKey: 'sk-test',
    );

    final respuesta = await service.classify(text: 'hola');

    expect(respuesta.tipoRespuesta, TipoRespuesta.conversacion);
    expect(respuesta.mensajeParaUsuario, 'Hola');
    expect(adapter.llamadas, 1);
  });

  test('tolera prosa alrededor del JSON', () async {
    final adapter = _FakeAdapter([
      _respuesta('Aquí va: $_jsonValido  Espero te sirva.'),
    ]);
    final service = LlmService(
      dio: Dio()..httpClientAdapter = adapter,
      apiKey: 'sk-test',
    );

    final respuesta = await service.classify(text: 'hola');

    expect(respuesta.tipoRespuesta, TipoRespuesta.conversacion);
  });
}
