import 'dart:io';

import 'package:finanzas_ia/services/llm_service.dart';
import 'package:finanzas_ia/services/supabase_repository.dart';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  final env = <String, String>{};
  for (final line in await File('.env').readAsLines()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final i = t.indexOf('=');
    if (i == -1) continue;
    env[t.substring(0, i).trim()] = t.substring(i + 1).trim();
  }

  final llm = LlmService(
    apiKey: env['LLM_API_KEY'] ?? '',
    baseUrl: env['LLM_BASE_URL'] ?? 'https://api.deepseek.com',
    model: env['LLM_MODEL'] ?? 'deepseek-chat',
  );
  final repo = SupabaseRepository(
    SupabaseClient(env['SUPABASE_URL']!, env['SUPABASE_ANON_KEY']!),
  );

  stdout.writeln('=== 1. Enrutamiento de consultas ===');
  for (final frase in [
    '¿cuál fue mi último egreso?',
    '¿cuál fue mi última venta?',
    '¿qué tal ves mi balance?',
    '¿cuánto gasté este mes?',
  ]) {
    final r = await llm.classify(text: frase);
    final d = r.datosConsulta;
    stdout.writeln('"$frase"');
    stdout.writeln('  -> ${r.tipoRespuesta} | tipo_consulta=${d?.tipoConsulta} '
        '| tipo=${d?.tipo} | reporte=${d?.tipoReporte}');
  }

  stdout.writeln('\n=== 2. Última transacción (repo real) ===');
  final ultima = await repo.ultimaTransaccion(tipo: 'egreso');
  if (ultima != null) {
    stdout.writeln('  último egreso: Q${ultima.monto} '
        'en ${ultima.categoria} (${ultima.fecha})');
  } else {
    stdout.writeln('  sin egresos');
  }

  stdout.writeln('\n=== 3. Resumen para análisis (repo real) ===');
  final resumen = await repo.obtenerResumenAnalisis();
  stdout.writeln('  ingresos Q${resumen.ingresos} (${resumen.cantidadIngresos}) '
      '| egresos Q${resumen.egresos} (${resumen.cantidadEgresos}) '
      '| balance Q${resumen.balance}');
  for (final c in resumen.porCategoria) {
    stdout.writeln('  - ${c.nombre} (${c.tipo}): Q${c.total} x${c.cantidad}');
  }

  stdout.writeln('\n=== 4. Análisis del LLM sobre el resumen ===');
  final buffer = StringBuffer()
    ..writeln('Resumen del mes actual (montos en quetzales):')
    ..writeln('Ingresos: Q${resumen.ingresos.toStringAsFixed(2)} '
        '(${resumen.cantidadIngresos} movimientos)')
    ..writeln('Egresos: Q${resumen.egresos.toStringAsFixed(2)} '
        '(${resumen.cantidadEgresos} movimientos)')
    ..writeln('Balance: Q${resumen.balance.toStringAsFixed(2)}');
  if (resumen.porCategoria.isNotEmpty) {
    buffer.writeln('Desglose por categoría:');
    for (final c in resumen.porCategoria) {
      buffer.writeln('- ${c.nombre} (${c.tipo}): '
          'Q${c.total.toStringAsFixed(2)} (${c.cantidad})');
    }
  }
  final analisis = await llm.analizar(resumen: buffer.toString());
  stdout.writeln(analisis);

  exit(0);
}
