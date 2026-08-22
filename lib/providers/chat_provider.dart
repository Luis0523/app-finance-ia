import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/llm_response.dart';
import '../services/llm_service.dart';

class PendingTransaction {
  const PendingTransaction({
    required this.messageId,
    required this.mensajeParaUsuario,
    required this.datos,
  });

  final String messageId;
  final String mensajeParaUsuario;
  final DatosTransaccion datos;

  PendingTransaction copyWith({
    String? messageId,
    String? mensajeParaUsuario,
    DatosTransaccion? datos,
  }) {
    return PendingTransaction(
      messageId: messageId ?? this.messageId,
      mensajeParaUsuario: mensajeParaUsuario ?? this.mensajeParaUsuario,
      datos: datos ?? this.datos,
    );
  }
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.inputText = '',
    this.isSending = false,
    this.pendingTransaction,
  });

  final List<ChatMessage> messages;
  final String inputText;
  final bool isSending;
  final PendingTransaction? pendingTransaction;

  bool get canSend => inputText.trim().isNotEmpty;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? inputText,
    bool? isSending,
    PendingTransaction? pendingTransaction,
    bool clearPendingTransaction = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      inputText: inputText ?? this.inputText,
      isSending: isSending ?? this.isSending,
      pendingTransaction: clearPendingTransaction
          ? null
          : pendingTransaction ?? this.pendingTransaction,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._llm) : super(const ChatState());

  static const _uuid = Uuid();
  final LlmService _llm;

  void setInputText(String text) {
    state = state.copyWith(inputText: text);
  }

  void addUserMessage(String text) {
    final message = ChatMessage(
      id: _uuid.v4(),
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      inputText: '',
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    addUserMessage(trimmed);
    state = state.copyWith(isSending: true);

    try {
      final response = await _llm.classify(text: trimmed);

      if (response.tipoRespuesta == TipoRespuesta.transaccion &&
          response.datosTransaccion != null) {
        state = state.copyWith(
          isSending: false,
          pendingTransaction: PendingTransaction(
            messageId: _uuid.v4(),
            mensajeParaUsuario: response.mensajeParaUsuario,
            datos: response.datosTransaccion!,
          ),
        );
        return;
      }

      _addAssistantMessage(
        response.mensajeParaUsuario.isEmpty
            ? _fallbackMessage(response.tipoRespuesta)
            : response.mensajeParaUsuario,
      );
    } on Exception catch (e) {
      _addAssistantMessage('Lo siento, hubo un error: $e');
    }
  }

  String _fallbackMessage(TipoRespuesta tipoRespuesta) {
    switch (tipoRespuesta) {
      case TipoRespuesta.transaccion:
        return 'Detecté una transacción. ¿Puedes repetirla con el monto?';
      case TipoRespuesta.conversacion:
        return 'Claro, dime en qué te ayudo con tu negocio.';
      case TipoRespuesta.consultaReporte:
        return 'La función de reportes aún no está disponible en este prototipo.';
    }
  }

  void _addAssistantMessage(String text, {String? tipoMovimiento}) {
    final message = ChatMessage(
      id: _uuid.v4(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      tipoMovimiento: tipoMovimiento,
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      isSending: false,
    );
  }

  void acceptPendingTransaction() {
    final pending = state.pendingTransaction;
    if (pending == null) return;

    final d = pending.datos;
    final monto = 'Q${d.monto.toStringAsFixed(2)}';
    final tipo = d.tipo == 'ingreso' ? 'Ingreso' : 'Egreso';
    final categoria = d.categoriaNivel2Sugerida.isNotEmpty
        ? '${d.categoriaNivel1Sugerida} › ${d.categoriaNivel2Sugerida}'
        : d.categoriaNivel1Sugerida;
    final text = '✓ Registrado: $tipo de $monto en $categoria.';

    state = state.copyWith(
      clearPendingTransaction: true,
      messages: [
        ...state.messages,
        ChatMessage(
          id: _uuid.v4(),
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
          tipoMovimiento: d.tipo,
        ),
      ],
    );
  }

  void updatePendingTransaction({
    required double monto,
    required String tipo,
    required String categoriaNivel1,
    required String categoriaNivel2,
  }) {
    final pending = state.pendingTransaction;
    if (pending == null) return;

    state = state.copyWith(
      pendingTransaction: pending.copyWith(
        datos: DatosTransaccion(
          monto: monto,
          tipo: tipo,
          categoriaNivel1Sugerida: categoriaNivel1,
          categoriaNivel2Sugerida: categoriaNivel2,
          confianza: pending.datos.confianza,
        ),
      ),
    );
  }

  void cancelPendingTransaction() {
    state = state.copyWith(clearPendingTransaction: true);
  }
}

final llmServiceProvider = Provider<LlmService>((ref) {
  return LlmService(
    apiKey: dotenv.env['LLM_API_KEY'] ?? '',
    baseUrl: dotenv.env['LLM_BASE_URL'] ?? 'https://api.deepseek.com',
    model: dotenv.env['LLM_MODEL'] ?? 'deepseek-chat',
  );
});

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(ref.watch(llmServiceProvider)),
);
