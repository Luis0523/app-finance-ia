import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/speech_service.dart';
import 'chat_provider.dart';

class SpeechRecognitionState {
  const SpeechRecognitionState({
    this.isInitialized = false,
    this.isListening = false,
    this.isWaitingPermission = false,
    this.transcribedText = '',
    this.localeId,
    this.errorMessage,
  });

  final bool isInitialized;
  final bool isListening;
  final bool isWaitingPermission;
  final String transcribedText;
  final String? localeId;
  final String? errorMessage;

  SpeechRecognitionState copyWith({
    bool? isInitialized,
    bool? isListening,
    bool? isWaitingPermission,
    String? transcribedText,
    String? localeId,
    String? errorMessage,
  }) {
    return SpeechRecognitionState(
      isInitialized: isInitialized ?? this.isInitialized,
      isListening: isListening ?? this.isListening,
      isWaitingPermission: isWaitingPermission ?? this.isWaitingPermission,
      transcribedText: transcribedText ?? this.transcribedText,
      localeId: localeId ?? this.localeId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SpeechRecognitionController
    extends StateNotifier<SpeechRecognitionState> {
  SpeechRecognitionController(this._service, this._chat)
      : super(const SpeechRecognitionState());

  final SpeechService _service;
  final ChatController _chat;

  Future<void> initialize() async {
    if (state.isInitialized) return;

    final ok = await _service.initialize();
    if (!ok) {
      state = state.copyWith(
        errorMessage: 'No se pudo inicializar el reconocimiento de voz.',
      );
      return;
    }

    final localeId = await _service.resolveSpanishLocale();
    state = state.copyWith(isInitialized: true, localeId: localeId);
  }

  Future<void> startListening() async {
    await initialize();
    if (!state.isInitialized) return;

    state = state.copyWith(
      isListening: true,
      transcribedText: '',
      errorMessage: null,
    );
    _chat.setInputText('');

    await _service.startListening(
      localeId: state.localeId ?? 'es_ES',
      onResult: (result) {
        final text = result.recognizedWords;
        state = state.copyWith(transcribedText: text);
        _chat.setInputText(text);
      },
    );
  }

  Future<void> stopListening() async {
    await _service.stopListening();
    state = state.copyWith(isListening: false);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final speechServiceProvider = Provider<SpeechService>(
  (ref) => SpeechService(),
);

final speechControllerProvider = StateNotifierProvider<
    SpeechRecognitionController, SpeechRecognitionState>(
  (ref) => SpeechRecognitionController(
    ref.watch(speechServiceProvider),
    ref.watch(chatControllerProvider.notifier),
  ),
);
