class UltimaTransaccion {
  const UltimaTransaccion({
    required this.monto,
    required this.tipo,
    required this.fecha,
    required this.categoriaNivel1,
    required this.categoriaNivel2,
    this.descripcion,
  });

  final double monto;
  final String tipo;
  final DateTime fecha;
  final String? categoriaNivel1;
  final String? categoriaNivel2;
  final String? descripcion;

  String get categoria {
    if (categoriaNivel2 != null && categoriaNivel2!.isNotEmpty) {
      return '$categoriaNivel1 › $categoriaNivel2';
    }
    return categoriaNivel1 ?? 'Sin categoría';
  }
}
