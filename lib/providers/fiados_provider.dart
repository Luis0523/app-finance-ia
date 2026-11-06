import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cuenta_por_cobrar.dart';
import 'supabase_provider.dart';

final fiadosProvider = FutureProvider.autoDispose<List<CuentaPorCobrar>>((ref) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  return repo.obtenerCuentasPorCobrar();
});
