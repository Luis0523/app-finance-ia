/// Datos genéricos para renderizar una tabla en el chat.
class TablaDatos {
  const TablaDatos({
    required this.titulo,
    required this.headers,
    required this.rows,
    this.columnaColor = -1,
    this.tipos = const [],
  });

  final String titulo;
  final List<String> headers;
  final List<List<String>> rows;

  /// Índice de la columna cuyo texto se colorea por tipo ('ingreso' verde,
  /// 'egreso' rojo). -1 para no colorear.
  final int columnaColor;

  /// 'ingreso' | 'egreso' | '' por fila (paralelo a [rows]).
  final List<String> tipos;
}
