import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/categoria.dart';
import 'supabase_provider.dart';

final categoriasProvider = FutureProvider<List<Categoria>>((ref) async {
  final data = await ref
      .watch(supabaseProvider)
      .from('categorias')
      .select('id, nombre, tipo')
      .isFilter('categoria_padre_id', null)
      .order('nombre');

  return data.map(Categoria.fromMap).toList();
});
