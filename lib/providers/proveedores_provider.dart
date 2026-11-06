import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/proveedor.dart';
import 'supabase_provider.dart';

final proveedoresProvider = FutureProvider<List<Proveedor>>((ref) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  return repo.obtenerProveedores();
});
