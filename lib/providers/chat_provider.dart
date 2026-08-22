import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/llm_response.dart';
import '../models/totales_mes.dart';
import '../services/llm_service.dart';
import '../services/supabase_repository.dart';
import 'supabase_provider.dart';

class PendingTransaction {
  const PendingTransaction({
    required this.messageId,
    required this.mensajeParaUsuario,
    required this.datos,
    required this.origen,
    required this.descripcionOriginal,
    this.conversacionId,
  });

  final String messageId;
  final String mensajeParaUsuario;
  final DatosTransaccion datos;
  final String origen;
  final String descripcionOriginal;
  final String? conversacionId;

  PendingTransaction copyWith({
    String? messageId,
    String? mensajeParaUsuario,
    DatosTransaccion? datos,
    String? origen,
    String? descripcionOriginal,
    String? conversacionId,
  }) {
    return PendingTransaction(
      messageId: messageId ?? this.messageId,
      mensajeParaUsuario: mensajeParaUsuario ?? this.mensajeParaUsuario,
      datos: datos ?? this.datos,
      origen: origen ?? this.origen,
      descripcionOriginal: descripcionOriginal ?? this.descripcionOriginal,
      conversacionId: conversacionId ?? this.conversacionId,
    );
  }
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.inputText = '',
    this.inputOrigen = 'texto',
    this.isSending = false,
    this.isSaving = false,
    this.pendingTransaction,
  });

  final List<ChatMessage> messages;
  final String inputText;

  /// 'voz' | 'texto'. Cómo se originó el texto actual del campo editable.
  final String inputOrigen;

  final bool isSending;
  final bool isSaving;
  final PendingTransaction? pendingTransaction;

  bool get canSend => inputText.trim().isNotEmpty;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? inputText,
    String? inputOrigen,
    bool? isSending,
    bool? isSaving,
    PendingTransaction? pendingTransaction,
    bool clearPendingTransaction = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      inputText: inputText ?? this.inputText,
      inputOrigen: inputOrigen ?? this.inputOrigen,
      isSending: isSending ?? this.isSending,
      isSaving: isSaving ?? this.isSaving,
      pendingTransaction: clearPendingTransaction
          ? null
          : pendingTransaction ?? this.pendingTransaction,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._llm, this._repo) : super(const ChatState());

  static const _uuid = Uuid();
  final LlmService _llm;
  final FinanzasRepository _repo;

  void setInputText(String text) {
    state = state.copyWith(inputText: text, inputOrigen: 'texto');
  }

  void setInputFromSpeech(String text) {
    state = state.copyWith(inputText: text, inputOrigen: 'voz');
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

    final origen = state.inputOrigen;
    addUserMessage(trimmed);
    final historial = _contextoPrevio();
    state = state.copyWith(isSending: true);

    try {
      final response = await _llm.classify(
        text: trimmed,
        historial: historial,
      );

      final intencion = _intencionDe(response.tipoRespuesta);
      String? conversacionId;
      try {
        conversacionId = await _repo.insertarConversacion(
          mensajeUsuario: trimmed,
          intencion: intencion,
          respuestaSistema: response.mensajeParaUsuario,
        );
      } on Exception {
        conversacionId = null;
      }

      if (response.tipoRespuesta == TipoRespuesta.transaccion &&
          response.datosTransaccion != null) {
        state = state.copyWith(
          isSending: false,
          pendingTransaction: PendingTransaction(
            messageId: _uuid.v4(),
            mensajeParaUsuario: response.mensajeParaUsuario,
            datos: response.datosTransaccion!,
            origen: origen,
            descripcionOriginal: trimmed,
            conversacionId: conversacionId,
          ),
        );
        return;
      }

      if (response.tipoRespuesta == TipoRespuesta.consultaReporte) {
        try {
          final totales = await _repo.obtenerTotalesMes();
          _addReportMessage(
            response.mensajeParaUsuario.isEmpty
                ? 'Estos son tus totales del mes.'
                : response.mensajeParaUsuario,
            totales,
          );
        } on Exception catch (e) {
          _addAssistantMessage('No se pudieron calcular los totales: $e');
        }
        return;
      }

      _addAssistantMessage(
        response.mensajeParaUsuario.isEmpty
            ? _fallbackMessage(response.tipoRespuesta)
            : response.mensajeParaUsuario,
      );
    } catch (e) {
      _addAssistantMessage('Lo siento, hubo un error: $e');
    }
  }

  /// Historial de mensajes previos al actual (excluye el mensaje recién
  /// enviado, que se pasa por separado al LLM). Limita a los últimos 20.
  List<ChatMessage> _contextoPrevio() {
    final todos = state.messages;
    if (todos.isEmpty) return const [];

    final previos = todos
        .take(todos.length - 1)
        .where((m) => m.text.trim().isNotEmpty)
        .toList();

    if (previos.length <= 20) return previos;
    return previos.sublist(previos.length - 20);
  }

  String _intencionDe(TipoRespuesta tipoRespuesta) {
    switch (tipoRespuesta) {
      case TipoRespuesta.transaccion:
        return 'transaccional';
      case TipoRespuesta.conversacion:
        return 'conversacional';
      case TipoRespuesta.consultaReporte:
        return 'consulta_reporte';
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

  void _addReportMessage(String text, TotalesMes totales) {
    final message = ChatMessage(
      id: _uuid.v4(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      reporte: totales,
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      isSending: false,
    );
  }

  Future<void> acceptPendingTransaction() async {
    final pending = state.pendingTransaction;
    if (pending == null) return;

    state = state.copyWith(clearPendingTransaction: true, isSaving: true);

    try {
      await _persistir(pending).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw PersistException(
          'Tiempo de espera agotado al guardar.',
        ),
      );

      final d = pending.datos;
      final monto = 'Q${d.monto.toStringAsFixed(2)}';
      final tipo = d.tipo == 'ingreso' ? 'Ingreso' : 'Egreso';
      final categoria = d.categoriaNivel2Sugerida.isNotEmpty
          ? '${d.categoriaNivel1Sugerida} › ${d.categoriaNivel2Sugerida}'
          : d.categoriaNivel1Sugerida;
      _addAssistantMessage(
        '✓ Registrado: $tipo de $monto en $categoria.',
        tipoMovimiento: d.tipo,
      );
    } catch (e) {
      state = state.copyWith(isSaving: false, pendingTransaction: pending);
      _addAssistantMessage('No se pudo guardar la transacción: $e');
    }
  }

  Future<void> _persistir(PendingTransaction pending) async {
    final categoriaId = await _repo.buscarOCrearCategoriaNivel2(
      categoriaNivel1: pending.datos.categoriaNivel1Sugerida,
      categoriaNivel2: pending.datos.categoriaNivel2Sugerida,
      tipo: pending.datos.tipo,
    );

    final transaccionId = await _repo.insertarTransaccion(
      categoriaId: categoriaId,
      monto: pending.datos.monto,
      tipo: pending.datos.tipo,
      descripcionOriginal: pending.descripcionOriginal,
      descripcionNormalizada: pending.mensajeParaUsuario,
      origen: pending.origen,
      confianza: pending.datos.confianza,
    );

    final conversacionId = pending.conversacionId;
    if (conversacionId != null) {
      await _repo.actualizarTransaccionEnConversacion(
        conversacionId: conversacionId,
        transaccionId: transaccionId,
      );
    }
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
  (ref) => ChatController(
    ref.watch(llmServiceProvider),
    ref.watch(supabaseRepositoryProvider),
  ),
);
