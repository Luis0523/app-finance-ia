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
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 45);
  }

  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;
  final String _model;

  String get apiKey => _apiKey;
  String get baseUrl => _baseUrl;
  String get model => _model;

  static const _toolName = 'clasificar_mensaje';

  static const systemPrompt = '''
Eres un asistente financiero para microempresarios guatemaltecos. Usa SIEMPRE la
herramienta clasificar_mensaje para responder, completando tipo_respuesta,
mensaje_para_usuario, datos_transaccion y datos_consulta.

Las categorías de nivel 1 disponibles son: Ingresos, Costos de venta, Gastos
operativos, Gastos administrativos, Otros gastos, Inversiones, Préstamos y
financiamiento, Retiros personales.

Si el mensaje describe una transacción de dinero (venta, compra, pago, gasto,
préstamo, retiro), usa tipo_respuesta = "transaccion" y llena datos_transaccion.
Cuando el mensaje mencione unidades y precio (ej. "compré 340 cosas a 10 quetzales
cada uno"), extrae "cantidad" (unidades) y "precio_unitario" (por unidad); el
"monto" siempre es el total (cantidad × precio_unitario). Redacta
mensaje_para_usuario de forma natural, amable y breve, confirmando el desglose
(ej. "Compré 340 × Q10.00 = Q3400.00, ¿correcto?").

Si detectas que parece una transacción pero falta el monto o datos clave, NO uses
"transaccion": usa "conversacion" y pregúntale al usuario de forma natural y
amable por lo que falta (ej. "¿De cuánto fue la venta?", "¿Cuántas unidades y a
qué precio?") para confirmar el procedimiento antes de registrar.
Si es un saludo, pregunta general o algo ambiguo sin datos financieros claros,
usa tipo_respuesta = "conversacion".
Si el usuario pide un reporte o resumen (totales, cuánto gastó/ganó), usa
tipo_respuesta = "consulta_reporte" y llena datos_consulta. Dentro de
datos_consulta elige tipo_consulta:
- "analisis" cuando pida opinión o evaluación ("¿qué tal ves mi balance?",
  "¿cómo voy?", "analízame").
- "ultima_transaccion" cuando pregunte por la última venta, compra, gasto o
  movimiento (usa "tipo": "ingreso" o "egreso" para filtrar).
- "totales" para montos o resúmenes numéricos del periodo.
- "listado" cuando pida la lista o detalle de ingresos/egresos/movimientos
  (usa "tipo": "ingreso" o "egreso" para filtrar).
- "flujo_caja" cuando pregunte por el flujo de caja o cómo va el dinero día a día.
- "viabilidad" cuando pregunte si puede comprar algo o si es viable comprar; llena
  "monto" con el costo total planeado.
- "inventario" cuando pregunte por existencias, productos o stock.

Usa los mensajes anteriores de la conversación como contexto para interpretar el
mensaje actual (por ejemplo, si el usuario dice "y esto" o "esa fruta", refiere a
algo ya mencionado).
''';

  static const _toolDefinicion = {
    'type': 'function',
    'function': {
      'name': _toolName,
      'description':
          'Clasifica el mensaje del microempresario y devuelve la estructura de respuesta.',
      'parameters': {
        'type': 'object',
        'properties': {
          'tipo_respuesta': {
            'type': 'string',
            'enum': ['transaccion', 'conversacion', 'consulta_reporte'],
          },
          'mensaje_para_usuario': {'type': 'string'},
          'datos_transaccion': {
            'type': ['object', 'null'],
            'properties': {
              'monto': {'type': 'number'},
              'tipo': {'type': 'string', 'enum': ['ingreso', 'egreso']},
              'categoria_nivel1_sugerida': {'type': 'string'},
              'categoria_nivel2_sugerida': {'type': 'string'},
              'confianza': {'type': 'number'},
              'cantidad': {'type': ['number', 'null']},
              'precio_unitario': {'type': ['number', 'null']},
            },
          },
          'datos_consulta': {
            'type': ['object', 'null'],
            'properties': {
              'tipo_consulta': {
                'type': 'string',
                'enum': [
                  'totales',
                  'ultima_transaccion',
                  'analisis',
                  'listado',
                  'flujo_caja',
                  'viabilidad',
                  'inventario',
                ],
              },
              'tipo_reporte': {
                'type': 'string',
                'enum': ['ingresos', 'egresos', 'ambos'],
              },
              'tipo': {
                'type': ['string', 'null'],
                'enum': ['ingreso', 'egreso'],
              },
              'periodo': {
                'type': 'string',
                'enum': ['hoy', 'mes_actual', 'mes_pasado'],
              },
              'categoria_nivel1': {'type': ['string', 'null']},
              'monto': {'type': ['number', 'null']},
            },
          },
        },
        'required': [
          'tipo_respuesta',
          'mensaje_para_usuario',
          'datos_transaccion',
          'datos_consulta',
        ],
      },
    },
  };

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
            'temperature': 0.2,
            'max_tokens': 1024,
            'tools': [_toolDefinicion],
            'tool_choice': {
              'type': 'function',
              'function': {'name': _toolName},
            },
          },
        );

        final message =
            response.data['choices'][0]['message'] as Map<String, dynamic>;
        String? content;
        final toolCalls = message['tool_calls'];
        if (toolCalls is List && toolCalls.isNotEmpty) {
          content =
              (toolCalls[0] as Map)['function']?['arguments']?.toString();
        }
        content ??= message['content']?.toString();
        final parsed = LlmResponse.fromJson(_extraerJson(content ?? ''));
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

  static const analisisPrompt = '''
Eres un analista financiero para microempresarios guatemaltecos. Recibes un
resumen numérico del negocio (montos en quetzales). Responde en español, breve
(máximo 4-5 líneas), en lenguaje natural y directo: señala el balance, cómo van
los ingresos frente a los egresos, las categorías más relevantes, cualquier riesgo
o alerta, y una recomendación concreta. No inventes números que no estén en el
resumen.
''';

  static const viabilidadPrompt = '''
Eres un asesor financiero para microempresarios guatemaltecos. Recibes un plan de
compra (monto en quetzales) y el resumen financiero del negocio (ingresos, egresos
y balance del mes; puede incluir el valor del inventario actual). Responde en
español, breve (máximo 4-5 líneas): indica si la compra es viable según el balance
y los ingresos, cuánto margen le quedaría, y una recomendación concreta (comprar
menos cantidad, priorizar proveedores, o que sí proceda). No inventes números que
no estén en el resumen.
''';

  Future<String> analizar({
    required String resumen,
    String? prompt,
  }) async {
    if (_apiKey.isEmpty || _apiKey.contains('tu_key')) {
      throw LlmException(
        'LLM_API_KEY no configurada en .env (usa la key de DeepSeek/OpenAI).',
      );
    }

    final systemPromptUsado = prompt ?? analisisPrompt;
    final endpoint = '${_baseUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions';

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
            'messages': [
              {'role': 'system', 'content': systemPromptUsado},
              {'role': 'user', 'content': resumen},
            ],
            'temperature': 0.6,
            'max_tokens': 600,
          },
        );

        final content = response.data['choices'][0]['message']['content'];
        final texto = content?.toString().trim() ?? '';
        if (texto.isNotEmpty) return texto;
        if (intento < _maxReintentos) {
          await _esperaReintento(intento);
          continue;
        }
        throw LlmException('El LLM devolvió un análisis vacío.');
      } on DioException catch (e) {
        if (intento < _maxReintentos) {
          await _esperaReintento(intento);
          continue;
        }
        throw LlmException(
          'Error del LLM: ${e.response?.statusCode ?? e.type} '
          '— ${e.response?.data ?? e.message}',
        );
      }
    }
    throw LlmException('No se pudo obtener el análisis del LLM.');
  }

  Future<void> _esperaReintento(int intento) {
    return Future.delayed(Duration(milliseconds: 600 * (intento + 1)));
  }

  /// Extrae el primer objeto JSON completo del texto, tolerando texto
  /// envolvente (prosa o code fences) que algunos modelos añaden.
  String _extraerJson(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceAll(RegExp(r'\n?```$'), '');
    }
    final inicio = text.indexOf('{');
    final fin = text.lastIndexOf('}');
    if (inicio != -1 && fin > inicio) {
      return text.substring(inicio, fin + 1);
    }
    return text;
  }
}
