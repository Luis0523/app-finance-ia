import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../main_shell.dart';
import 'auth_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autenticado = ref.watch(autenticadoProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: autenticado
          ? const MainShell(key: ValueKey('app'))
          : const AuthScreen(key: ValueKey('auth')),
    );
  }
}
