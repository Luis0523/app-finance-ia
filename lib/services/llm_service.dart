import 'package:dio/dio.dart';

import '../models/chat_message.dart';
import '../models/llm_response.dart';
import '../utils/currency.dart';

class LlmException implements Exception {
  LlmException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LlmService {
  LlmService({
    Dio? dio,
    String apiKey = '',
    String baseUrl = 'https://api.deepseek.com',
    String model = 'deepseek-chat',
  })  : _dio = dio ?? Dio(),
        // ignore: prefer_initializing_formals
        _apiKey = apiKey,
        // ignore: prefer_initializing_formals
        _baseUrl = baseUrl,
        // ignore: prefer_initializing_formals
        _model = model {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 90);
  }

  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;
  final String _model;

  String get apiKey => _apiKey;
  String get baseUrl => _baseUrl;
  String get model => _model;

  static const systemPrompt = '''
Eres un asistente que clasifica mensajes de microempresarios guatemaltecos sobre
su negocio. Debes responder EXCLUSIVAMENTE en JSON válido, sin texto adicional,
siguiendo este esquema exacto: {"tipo_respuesta", "mensaje_para_usuario", "datos_transaccion", "datos_consulta"}.

Las categorías de nivel 1 disponibles son: Ingresos, Costos de venta, Gastos
operativos, Gastos administrativos, Otros gastos, Inversiones, Préstamos y
financiamiento, Retiros personales.

Si el mensaje describe una transacción de dinero (venta, compra, pago, gasto,
préstamo, retiro), usa tipo_respuesta = "transaccion", llena datos_transaccion
y deja datos_consulta = null.
Si el mensaje es un saludo, pregunta general o algo ambiguo sin datos financieros
claros, usa tipo_respuesta = "conversacion" y tanto datos_transaccion como
datos_consulta = null.
Si el usuario pide ver un reporte o resumen (totales, cuánto gastó/ganó, resumen
de ingresos o egresos), usa tipo_respuesta = "consulta_reporte", deja
datos_transaccion = null y llena datos_consulta.

Usa los mensajes anteriores de la conversación como contexto para interpretar el
mensaje actual (por ejemplo, si el usuario dice "y esto" o "la otra venta",
refiere a algo ya mencionado). Clasifica siempre el mensaje actual con el esquema
JSON indicado, nunca respondas por los mensajes previos.

Formato exacto de datos_transaccion cuando es transaccion:
{
  "monto": <número en quetzales>,
  "tipo": "ingreso" o "egreso",
  "categoria_nivel1_sugerida": "<una de las 8 categorías de nivel 1>",
  "categoria_nivel2_sugerida": "<subcategoría razonable para un negocio>",
  "confianza": <número entre 0 y 1>
}

Formato exacto de datos_consulta cuando es consulta_reporte:
{
  "tipo_reporte": "ingresos" o "egresos" o "ambos",
  "periodo": "hoy" o "mes_actual" o "mes_pasado",
  "categoria_nivel1": "<una de las 8 categorías de nivel 1 o null>"
}
''';

  Future<LlmResponse> classify({
    required String text,
    List<ChatMessage> historial = const [],
  }) async {
    if (_apiKey.isEmpty || _apiKey.contains('tu_key')) {
      throw LlmException(
        'LLM_API_KEY no configurada en .env (usa la key de DeepSeek/OpenAI).',
      );
    }

    final endpoint = '${_baseUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];
    for (final mensaje in historial) {
      messages.add({
        'role': mensaje.isUser ? 'user' : 'assistant',
        'content': mensaje.text,
      });
    }
    messages.add({'role': 'user', 'content': text});

    for (var intento = 0; intento <= _maxReintentos; intento++) {
      try {
        final response = await _dio.post(
          endpoint,
          options: Options(
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
          ),
          data: {
            'model': _model,
            'messages': messages,
            'response_format': {'type': 'json_object'},
            'temperature': 0.2,
            'max_tokens': 1024,
          },
        );

        final content =
            response.data['choices'][0]['message']['content'] as String;
        final parsed = LlmResponse.fromJson(_cleanJson(content));
        return LlmResponse(
          tipoRespuesta: parsed.tipoRespuesta,
          mensajeParaUsuario: normalizeCurrencyText(parsed.mensajeParaUsuario),
          datosTransaccion: parsed.datosTransaccion,
          datosConsulta: parsed.datosConsulta,
        );
      } on DioException catch (e) {
        if (intento < _maxReintentos) {
          await _esperaReintento(intento);
          continue;
        }
        throw LlmException(
          'Error del LLM: ${e.response?.statusCode ?? e.type} '
          '— ${e.response?.data ?? e.message}',
        );
      } on FormatException catch (e) {
        if (intento < _maxReintentos) {
          await _esperaReintento(intento);
          continue;
        }
        throw LlmException(
          'La respuesta del LLM no es JSON válido: ${e.message}',
        );
      } catch (e) {
        if (intento < _maxReintentos) {
          await _esperaReintento(intento);
          continue;
        }
        throw LlmException('Error inesperado al clasificar: $e');
      }
    }
    throw LlmException('No se pudo obtener una respuesta válida del LLM.');
  }

  static const _maxReintentos = 2;

  Future<void> _esperaReintento(int intento) {
    return Future.delayed(Duration(milliseconds: 600 * (intento + 1)));
  }

  String _cleanJson(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceAll(RegExp(r'\n?```$'), '');
    }
    return text;
  }
}
