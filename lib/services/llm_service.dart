import 'package:dio/dio.dart';

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
        _model = model;

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
siguiendo este esquema exacto: {"tipo_respuesta", "mensaje_para_usuario", "datos_transaccion"}.

Las categorías de nivel 1 disponibles son: Ingresos, Costos de venta, Gastos
operativos, Gastos administrativos, Otros gastos, Inversiones, Préstamos y
financiamiento, Retiros personales.

Si el mensaje describe una transacción de dinero (venta, compra, pago, gasto,
préstamo, retiro), usa tipo_respuesta = "transaccion" y llena datos_transaccion.
Si el mensaje es un saludo, pregunta general o algo ambiguo sin datos financieros
claros, usa tipo_respuesta = "conversacion" y datos_transaccion = null.
Si el usuario pide ver un reporte o resumen, usa tipo_respuesta = "consulta_reporte"
y datos_transaccion = null.

Formato exacto de datos_transaccion cuando es transaccion:
{
  "monto": <número en quetzales>,
  "tipo": "ingreso" o "egreso",
  "categoria_nivel1_sugerida": "<una de las 8 categorías de nivel 1>",
  "categoria_nivel2_sugerida": "<subcategoría razonable para un negocio>",
  "confianza": <número entre 0 y 1>
}
''';

  Future<LlmResponse> classify({required String text}) async {
    if (_apiKey.isEmpty || _apiKey.contains('tu_key')) {
      throw LlmException(
        'LLM_API_KEY no configurada en .env (usa la key de DeepSeek/OpenAI).',
      );
    }

    final endpoint = '${_baseUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions';

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
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': text},
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.2,
        },
      );

      final content =
          response.data['choices'][0]['message']['content'] as String;
      final parsed = LlmResponse.fromJson(_cleanJson(content));
      return LlmResponse(
        tipoRespuesta: parsed.tipoRespuesta,
        mensajeParaUsuario: normalizeCurrencyText(parsed.mensajeParaUsuario),
        datosTransaccion: parsed.datosTransaccion,
      );
    } on DioException catch (e) {
      throw LlmException(
        'Error del LLM: ${e.response?.statusCode ?? e.type} '
        '— ${e.response?.data ?? e.message}',
      );
    } on FormatException catch (e) {
      throw LlmException('La respuesta del LLM no es JSON válido: ${e.message}');
    } catch (e) {
      throw LlmException('Error inesperado al clasificar: $e');
    }
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
