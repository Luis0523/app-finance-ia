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

  final client = SupabaseClient(env['SUPABASE_URL']!, env['SUPABASE_ANON_KEY']!);
  final repo = SupabaseRepository(client);

  final totales = await repo.obtenerTotalesMes();

  stdout.writeln('Totales del mes actual:');
  stdout.writeln('  Ingresos: Q${totales.ingresos.toStringAsFixed(2)} (${totales.cantidadIngresos} movimientos)');
  stdout.writeln('  Egresos:  Q${totales.egresos.toStringAsFixed(2)} (${totales.cantidadEgresos} movimientos)');
  stdout.writeln('  Balance:  Q${totales.balance.toStringAsFixed(2)}');

  // Comparación manual: sumamos las filas del mes en Dart
  final sql = await client.from('transacciones').select('tipo,monto')
      .eq('confirmado_por_usuario', true)
      .gte('fecha', '${DateTime.now().year.toString().padLeft(4, "0")}-${DateTime.now().month.toString().padLeft(2, "0")}-01');

  double sumaIngresos = 0;
  double sumaEgresos = 0;
  for (final row in sql) {
    final valor = (row['monto'] as num?)?.toDouble() ?? 0;
    if (row['tipo'] == 'ingreso') sumaIngresos += valor;
    if (row['tipo'] == 'egreso') sumaEgresos += valor;
  }

  final ok = (totales.ingresos - sumaIngresos).abs() < 0.01 &&
      (totales.egresos - sumaEgresos).abs() < 0.01;

  stdout.writeln('\nSuma SQL manual: ingresos Q$sumaIngresos, egresos Q$sumaEgresos');
  if (!ok) {
    stderr.writeln('ERROR: los totales no coinciden con la suma manual.');
    exit(1);
  }
  stdout.writeln('FASE 4 OK');
  exit(0);
}
