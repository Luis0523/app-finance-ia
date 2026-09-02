import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/producto_inventario.dart';
import 'supabase_provider.dart';

final inventarioProvider = FutureProvider<List<ProductoInventario>>((
  ref,
) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  return repo.inventario();
});
