import 'dart:io';

import 'package:finanzas_ia/models/chat_message.dart';
import 'package:finanzas_ia/services/llm_service.dart';

Future<void> main() async {
  final env = <String, String>{};
  final lines = await File('.env').readAsLines();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx == -1) continue;
    env[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
  }

  final service = LlmService(
    apiKey: env['LLM_API_KEY'] ?? '',
    baseUrl: env['LLM_BASE_URL'] ?? 'https://api.deepseek.com',
    model: env['LLM_MODEL'] ?? 'deepseek-chat',
  );

  final frases = [
    'hola, buenos días',
    'vendí Q200 de fruta hoy',
    'esa fruta la compré a Q120 en el mercado',
    'pagué la luz del negocio, Q150',
    '¿cuánto llevo de ingresos este mes?',
    'hola, ¿cómo estás?',
    'compré mercadería por Q300',
    'me pagaron Q80 de una venta a crédito',
    'saqué Q200 para mis gastos personales',
    '¿cuánto gasté este mes?',
  ];

  final historial = <ChatMessage>[];
  for (var i = 0; i < frases.length; i++) {
    final frase = frases[i];
    stdout.writeln('\n[$i/${frases.length}] "$frase"');
    try {
      final r = await service.classify(text: frase, historial: historial);
      stdout.writeln('  -> ${r.tipoRespuesta} | ${r.mensajeParaUsuario}');
      historial.add(ChatMessage(
        id: 'u$i',
        text: frase,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      historial.add(ChatMessage(
        id: 'a$i',
        text: r.mensajeParaUsuario,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      stdout.writeln('  -> ERROR: $e');
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }
  stdout.writeln('\nFIN (${historial.length} mensajes en historial)');
  exit(0);
}
