import 'dart:io';

import 'package:supabase/supabase.dart';

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

  final url = env['SUPABASE_URL'];
  final key = env['SUPABASE_ANON_KEY'];
  if (url == null || key == null) {
    stderr.writeln('ERROR: .env no tiene SUPABASE_URL o SUPABASE_ANON_KEY');
    exit(1);
  }

  final client = SupabaseClient(url, key);
  final rows = await client
      .from('categorias')
      .select('id, nombre, tipo')
      .isFilter('categoria_padre_id', null)
      .order('nombre');

  stdout.writeln('Conectado a Supabase: $url');
  stdout.writeln('Categorías nivel 1 encontradas: ${rows.length}');
  for (final row in rows) {
    stdout.writeln('  - ${row['nombre']} (${row['tipo']})');
  }

  if (rows.length != 8) {
    stderr.writeln('ERROR: se esperaban 8 categorías, se encontraron ${rows.length}');
    exit(1);
  }

  stdout.writeln('VERIFICACIÓN FASE 0 OK');
  exit(0);
}
