import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_ia/main.dart';
import 'package:finanzas_ia/models/chat_message.dart';
import 'package:finanzas_ia/models/llm_response.dart';
import 'package:finanzas_ia/providers/chat_provider.dart';
import 'package:finanzas_ia/providers/negocio_provider.dart';
import 'package:finanzas_ia/providers/speech_provider.dart';
import 'package:finanzas_ia/providers/supabase_provider.dart';
import 'package:finanzas_ia/screens/chat_screen.dart';
import 'package:finanzas_ia/screens/home_screen.dart';
import 'package:finanzas_ia/screens/main_shell.dart';
import 'package:finanzas_ia/services/llm_service.dart';
import 'package:finanzas_ia/services/speech_service.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'fakes/fake_repository.dart';

class _FakeSpeechService extends SpeechService {
  _FakeSpeechService();

  @override
  bool get isInitialized => true;

  @override
  Future<bool> initialize({SpeechStatusListener? onStatus}) async => true;

  @override
  Future<String> resolveSpanishLocale() async => 'es_ES';
}

class _FakeLlmService extends LlmService {
  _FakeLlmService();

  @override
  Future<LlmResponse> classify({
    required String text,
    List<ChatMessage> historial = const [],
  }) async {
    return const LlmResponse(
      tipoRespuesta: TipoRespuesta.conversacion,
      mensajeParaUsuario: 'Entendido, ¿quieres registrar algo más?',
      datosTransaccion: null,
    );
  }
}

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechServiceProvider.overrideWithValue(_FakeSpeechService()),
          llmServiceProvider.overrideWithValue(_FakeLlmService()),
          supabaseRepositoryProvider.overrideWithValue(FakeRepository()),
          negocioNombreProvider.overrideWith(
            (ref) async => 'Tienda de Doña María',
          ),
        ],
        child: const FinanzasApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('app builds with MainShell and HomeScreen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('navegar al asistente muestra el chat con micrófono', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('escribir y enviar agrega burbuja del usuario', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'vendí Q200 de fruta hoy');
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('vendí Q200 de fruta hoy'), findsOneWidget);
    expect(
      find.text('Entendido, ¿quieres registrar algo más?'),
      findsOneWidget,
    );
  });
}
