class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.tipoMovimiento,
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  /// 'ingreso' | 'egreso' | null. Se usa para pintar el borde de la burbuja.
  final String? tipoMovimiento;
}
