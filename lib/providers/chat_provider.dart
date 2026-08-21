import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';

class ChatState {
  const ChatState({this.messages = const [], this.inputText = ''});

  final List<ChatMessage> messages;
  final String inputText;

  bool get canSend => inputText.trim().isNotEmpty;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? inputText,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      inputText: inputText ?? this.inputText,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController() : super(const ChatState());

  static const _uuid = Uuid();

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
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(),
);
