import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<bool> initialize({SpeechStatusListener? onStatus}) async {
    _initialized = await _speech.initialize(
      debugLogging: false,
      onStatus: onStatus,
    );
    return _initialized;
  }

  Future<String> resolveSpanishLocale() async {
    if (!_initialized) return 'es_ES';
    final locales = await _speech.locales();
    const preferred = ['es_GT', 'es_MX', 'es_ES', 'es'];
    for (final prefix in preferred) {
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith(prefix.toLowerCase())) {
          return locale.localeId;
        }
      }
    }
    if (locales.isNotEmpty) return locales.first.localeId;
    return 'es_ES';
  }

  /// Duración de silencio que detiene la escucha automáticamente.
  static const pauseFor = Duration(seconds: 2);

  Future<void> startListening({
    required String localeId,
    required void Function(SpeechRecognitionResult result) onResult,
    void Function(double level)? onSoundLevelChange,
  }) async {
    await _speech.listen(
      onResult: onResult,
      onSoundLevelChange: onSoundLevelChange,
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        pauseFor: pauseFor,
      ),
    );
  }

  Future<void> stopListening() => _speech.stop();

  Future<void> cancelListening() => _speech.cancel();
}
