import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'supabase_provider.dart';

final negocioNombreProvider = FutureProvider<String>((ref) async {
  final usuario = ref.watch(usuarioActualProvider);
  if (usuario == null) return 'Mi negocio';

  final client = ref.watch(supabaseProvider);
  final negocios = await client
      .from('negocios')
      .select('nombre')
      .order('creado_en')
      .limit(1);
  if (negocios.isEmpty) return 'Mi negocio';
  return negocios.first['nombre']?.toString() ?? 'Mi negocio';
});
