import 'dart:io';

import 'package:finanzas_ia/models/chat_message.dart';
import 'package:finanzas_ia/models/llm_response.dart';
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

  stdout.writeln('--- Mensaje 1 ---');
  final r1 = await service.classify(text: 'vendí Q200 de fruta hoy');
  stdout.writeln('tipo: ${r1.tipoRespuesta} | msg: ${r1.mensajeParaUsuario}');

  final historial = [
    ChatMessage(
      id: '1',
      text: 'vendí Q200 de fruta hoy',
      isUser: true,
      timestamp: DateTime.now(),
    ),
    ChatMessage(
      id: '2',
      text: r1.mensajeParaUsuario,
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  stdout.writeln('--- Mensaje 2 (con contexto de la venta anterior) ---');
  final r2 = await service.classify(
    text: 'esa fruta la compré a Q120 en el mercado',
    historial: historial,
  );
  stdout.writeln('tipo: ${r2.tipoRespuesta} | msg: ${r2.mensajeParaUsuario}');
  if (r2.tipoRespuesta == TipoRespuesta.transaccion &&
      r2.datosTransaccion != null) {
    final d = r2.datosTransaccion!;
    stdout.writeln('datos: Q${d.monto} ${d.tipo} '
        '| ${d.categoriaNivel1Sugerida} › ${d.categoriaNivel2Sugerida}');
  }

  exit(0);
}
