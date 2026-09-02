import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_provider.dart';

final negocioNombreProvider = FutureProvider<String>((ref) async {
  final client = ref.watch(supabaseProvider);
  final negocios = await client
      .from('negocios')
      .select('nombre')
      .order('creado_en')
      .limit(1);
  if (negocios.isEmpty) return 'Mi negocio';
  return negocios.first['nombre']?.toString() ?? 'Mi negocio';
});
