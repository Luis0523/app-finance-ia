import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_ia/main.dart';
import 'package:finanzas_ia/models/llm_response.dart';
import 'package:finanzas_ia/providers/chat_provider.dart';
import 'package:finanzas_ia/providers/speech_provider.dart';
import 'package:finanzas_ia/providers/supabase_provider.dart';
import 'package:finanzas_ia/screens/chat_screen.dart';
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
  Future<LlmResponse> classify({required String text}) async {
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
        ],
        child: const FinanzasApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ChatScreen builds with mic and disabled send button',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    final sendButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('Typing enables send and adds a user message bubble',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byType(TextField),
      'vendí Q200 de fruta hoy',
    );
    await tester.pump();

    final sendButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send),
    );
    expect(sendButton.onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('vendí Q200 de fruta hoy'), findsOneWidget);
    expect(find.text('Entendido, ¿quieres registrar algo más?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
