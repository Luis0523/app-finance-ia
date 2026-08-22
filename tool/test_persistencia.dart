import 'dart:io';

import 'package:finanzas_ia/services/supabase_repository.dart';
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
    stderr.writeln('ERROR: .env sin SUPABASE_URL o SUPABASE_ANON_KEY');
    exit(1);
  }

  final client = SupabaseClient(url, key);
  final repo = SupabaseRepository(client);

  // 1. Categoría nivel 2 (crear o buscar)
  final categoriaId = await repo.buscarOCrearCategoriaNivel2(
    categoriaNivel1: 'Ingresos',
    categoriaNivel2: 'Venta de producto',
    tipo: 'ingreso',
  );
  stdout.writeln('categoria_id: $categoriaId');

  // 2. Transacción (confirmada por usuario, origen voz)
  final transaccionId = await repo.insertarTransaccion(
    categoriaId: categoriaId,
    monto: 200,
    tipo: 'ingreso',
    descripcionOriginal: 'vendí Q200 de fruta hoy',
    descripcionNormalizada: 'Detecté una venta de Q200. ¿Confirmas?',
    origen: 'voz',
    confianza: 0.95,
  );
  stdout.writeln('transaccion_id: $transaccionId');

  // 3. Conversación log + vínculo con la transacción
  final conversacionId = await repo.insertarConversacion(
    mensajeUsuario: 'vendí Q200 de fruta hoy',
    intencion: 'transaccional',
    respuestaSistema: 'Detecté una venta de Q200. ¿Confirmas?',
  );
  stdout.writeln('conversacion_id: $conversacionId');

  await repo.actualizarTransaccionEnConversacion(
    conversacionId: conversacionId,
    transaccionId: transaccionId,
  );

  // 4. Verificar en la BD
  final tx = await client
      .from('transacciones')
      .select('id, monto, tipo, origen, confirmado_por_usuario')
      .eq('id', transaccionId)
      .single();
  final conv = await client
      .from('conversaciones')
      .select('id, intencion_detectada, transaccion_id')
      .eq('id', conversacionId)
      .single();

  stdout.writeln('VERIFICACIÓN PUNTA A PUNTA');
  stdout.writeln('transaccion: $tx');
  stdout.writeln('conversacion: $conv');

  if ((tx['monto'] as num).toDouble() != 200.0 ||
      tx['confirmado_por_usuario'] != true ||
      conv['transaccion_id'] != transaccionId) {
    stderr.writeln('ERROR: los datos no coinciden con lo esperado.');
    exit(1);
  }

  stdout.writeln('FASE 3 OK');
  exit(0);
}
