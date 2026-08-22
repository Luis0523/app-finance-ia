import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/chat_message.dart';
import '../models/tabla_datos.dart';
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

  Future<void> _onSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final controller = ref.read(chatControllerProvider.notifier);
    controller.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _onConfirmPending() async {
    ref.read(chatControllerProvider.notifier).acceptPendingTransaction();
    _scrollToBottom();
  }

  Future<void> _onCorrectPending() async {
    final pending = ref.read(chatControllerProvider).pendingTransaction;
    if (pending == null) return;
    await _showCorrectionDialog(pending);
  }

  Future<void> _showCorrectionDialog(PendingTransaction pending) async {
    final montoController = TextEditingController(
      text: pending.datos.monto.toStringAsFixed(2),
    );
    final nivel2Controller = TextEditingController(
      text: pending.datos.categoriaNivel2Sugerida,
    );
    var tipo = pending.datos.tipo;
    var categoriaNivel1 = pending.datos.categoriaNivel1Sugerida;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Corregir transacción'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: montoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto (Q)',
                    prefixText: 'Q ',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                    DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => tipo = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nivel2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Categoría (nivel 2)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoriaNivel1,
                  decoration: const InputDecoration(labelText: 'Categoría nivel 1'),
                  items: _nivel1Categorias(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => categoriaNivel1 = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardado != true) return;

    final monto = double.tryParse(montoController.text.trim()) ?? 0;
    ref
        .read(chatControllerProvider.notifier)
        .updatePendingTransaction(
          monto: monto,
          tipo: tipo,
          categoriaNivel1: categoriaNivel1,
          categoriaNivel2: nivel2Controller.text.trim(),
        );
  }

  List<DropdownMenuItem<String>> _nivel1Categorias() {
    const categorias = [
      'Ingresos',
      'Costos de venta',
      'Gastos operativos',
      'Gastos administrativos',
      'Otros gastos',
      'Inversiones',
      'Préstamos y financiamiento',
      'Retiros personales',
    ];
    return categorias
        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
        .toList();
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
                    itemBuilder: (context, index) {
                      final message = chat.messages[index];
                      if (message.tabla != null) {
                        return _TablaCard(message: message);
                      }
                      if (message.reporte != null) {
                        return _ReporteCard(message: message);
                      }
                      return _MessageBubble(message: message);
                    },
                  ),
          ),
          if (chat.isSending) const _TypingIndicator(),
          if (chat.pendingTransaction != null)
            _TransactionCard(
              pending: chat.pendingTransaction!,
              isSaving: chat.isSaving,
              onConfirm: _onConfirmPending,
              onCorrect: _onCorrectPending,
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
    final tipo = message.tipoMovimiento;
    final borderColor = tipo == 'ingreso'
        ? Colors.green
        : tipo == 'egreso'
            ? theme.colorScheme.error
            : null;

    final contenido = borderColor != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tipo == 'ingreso' ? Icons.trending_up : Icons.trending_down,
                size: 18,
                color: borderColor,
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(message.text)),
            ],
          )
        : Text(message.text);

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
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1.5)
            : null,
      ),
      child: contenido,
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

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Clasificando...', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.pending,
    required this.isSaving,
    required this.onConfirm,
    required this.onCorrect,
  });

  final PendingTransaction pending;
  final bool isSaving;
  final VoidCallback onConfirm;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = pending.datos;
    final isIngreso = d.tipo == 'ingreso';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isIngreso ? Colors.green.shade200 : theme.colorScheme.error,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isIngreso ? Icons.trending_up : Icons.trending_down,
                  color: isIngreso ? Colors.green : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pending.mensajeParaUsuario,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DataRow(label: 'Monto', value: 'Q${d.monto.toStringAsFixed(2)}'),
            _DataRow(label: 'Tipo', value: isIngreso ? 'Ingreso' : 'Egreso'),
            _DataRow(
              label: 'Categoría',
              value: d.categoriaNivel2Sugerida.isNotEmpty
                  ? '${d.categoriaNivel1Sugerida} › ${d.categoriaNivel2Sugerida}'
                  : d.categoriaNivel1Sugerida,
            ),
            _DataRow(
              label: 'Confianza',
              value: '${(d.confianza * 100).toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onCorrect,
                  icon: const Icon(Icons.edit),
                  label: const Text('Corregir'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : onConfirm,
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(isSaving ? 'Guardando...' : 'Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TablaCard extends StatelessWidget {
  const _TablaCard({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabla = message.tabla!;

    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.text.isNotEmpty)
                Text(message.text, style: theme.textTheme.bodyLarge),
              if (message.text.isNotEmpty) const SizedBox(height: 8),
              Text(
                tabla.titulo,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildTabla(tabla, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabla(TablaDatos tabla, ThemeData theme) {
    final borderColor = theme.colorScheme.outlineVariant;

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.all(color: borderColor),
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
          children: [
            for (final header in tabla.headers)
              _celda(
                Text(header,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        for (var i = 0; i < tabla.rows.length; i++)
          TableRow(
            children: [
              for (var c = 0; c < tabla.rows[i].length; c++)
                _celda(
                  Text(
                    tabla.rows[i][c],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _colorCelda(tabla, i, c, theme),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Color? _colorCelda(TablaDatos tabla, int fila, int col, ThemeData theme) {
    if (tabla.columnaColor != col) return null;
    final tipo = fila < tabla.tipos.length ? tabla.tipos[fila] : '';
    if (tipo == 'ingreso') return Colors.green.shade700;
    if (tipo == 'egreso') return theme.colorScheme.error;
    return null;
  }

  Widget _celda(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: child,
    );
  }
}

class _ReporteCard extends StatelessWidget {
  const _ReporteCard({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totales = message.reporte!;

    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.text.isNotEmpty)
                Text(message.text, style: theme.textTheme.bodyLarge),
              if (message.text.isNotEmpty) const SizedBox(height: 12),
              _TotalRow(
                label: 'Ingresos',
                monto: totales.ingresos,
                color: Colors.green,
                cantidad: totales.cantidadIngresos,
              ),
              const SizedBox(height: 8),
              _TotalRow(
                label: 'Egresos',
                monto: totales.egresos,
                color: theme.colorScheme.error,
                cantidad: totales.cantidadEgresos,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              _TotalRow(
                label: 'Balance',
                monto: totales.balance,
                color: totales.balance >= 0 ? Colors.green : theme.colorScheme.error,
                cantidad: null,
                bold: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.monto,
    required this.color,
    this.cantidad,
    this.bold = false,
  });

  final String label;
  final double monto;
  final Color color;
  final int? cantidad;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estilo = (bold
            ? theme.textTheme.titleMedium
            : theme.textTheme.bodyLarge)!
        .copyWith(color: color, fontWeight: bold ? FontWeight.bold : null);

    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        if (cantidad != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '($cantidad)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Text('Q${monto.toStringAsFixed(2)}', style: estilo),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
