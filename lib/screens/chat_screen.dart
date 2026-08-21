import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/speech_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(speechControllerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onMicPressed() async {
    final speech = ref.read(speechControllerProvider);

    if (speech.isListening) {
      await ref.read(speechControllerProvider.notifier).stopListening();
      return;
    }

    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showMessage('Se necesita el permiso del micrófono para transcribir tu voz.');
        return;
      }
    }

    try {
      await ref.read(speechControllerProvider.notifier).startListening();
    } catch (_) {
      _showMessage('No se pudo iniciar el reconocimiento de voz en este dispositivo.');
    }
  }

  void _onSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ref.read(chatControllerProvider.notifier).addUserMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SpeechRecognitionState>(speechControllerProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        _showMessage(next.errorMessage!);
      }
    });

    ref.listen<ChatState>(chatControllerProvider, (prev, next) {
      if (next.inputText != _textController.text) {
        _textController.value = TextEditingValue(
          text: next.inputText,
          selection: TextSelection.collapsed(offset: next.inputText.length),
        );
      }
    });

    final speech = ref.watch(speechControllerProvider);
    final chat = ref.watch(chatControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Asistente financiero')),
      body: Column(
        children: [
          if (speech.isListening) _ListeningBanner(localeId: speech.localeId),
          Expanded(
            child: chat.messages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: chat.messages[index]),
                  ),
          ),
          _InputBar(
            textController: _textController,
            canSend: chat.canSend,
            isListening: speech.isListening,
            onMicPressed: _onMicPressed,
            onSend: _onSend,
            onChanged: (value) =>
                ref.read(chatControllerProvider.notifier).setInputText(value),
          ),
        ],
      ),
    );
  }
}

class _ListeningBanner extends StatelessWidget {
  const _ListeningBanner({this.localeId});

  final String? localeId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Escuchando... (${localeId ?? 'es'})',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Pulsa el micrófono y di tu transacción, '
              'por ejemplo: "vendí Q200 de fruta hoy"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.8,
      ),
      decoration: BoxDecoration(
        color: isUser
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.text,
        style: theme.textTheme.bodyLarge,
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.textController,
    required this.canSend,
    required this.isListening,
    required this.onMicPressed,
    required this.onSend,
    required this.onChanged,
  });

  final TextEditingController textController;
  final bool canSend;
  final bool isListening;
  final VoidCallback onMicPressed;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: onMicPressed,
              tooltip: isListening ? 'Detener grabación' : 'Hablar',
              icon: Icon(
                isListening ? Icons.stop_circle : Icons.mic,
                color: isListening ? theme.colorScheme.error : null,
              ),
            ),
            Expanded(
              child: TextField(
                controller: textController,
                onChanged: onChanged,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => canSend ? onSend() : null,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Corrige o escribe tu transacción...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: canSend ? onSend : null,
              tooltip: 'Enviar',
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
