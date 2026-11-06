import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_repository.dart';
import 'auth_provider.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseRepositoryProvider = Provider<FinanzasRepository>((ref) {
  ref.watch(usuarioActualProvider);
  return SupabaseRepository(ref.watch(supabaseProvider));
});
