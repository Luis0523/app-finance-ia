class ListadoTransaccion {
  const ListadoTransaccion({
    required this.fecha,
    required this.tipo,
    required this.monto,
    this.categoriaNivel1,
    this.categoriaNivel2,
    this.descripcion,
    this.origen,
    this.cantidad,
    this.precioUnitario,
  });

  final DateTime fecha;
  final String tipo;
  final double monto;
  final String? categoriaNivel1;
  final String? categoriaNivel2;
  final String? descripcion;
  final String? origen;
  final double? cantidad;
  final double? precioUnitario;

  String get categoria {
    if (categoriaNivel2 != null && categoriaNivel2!.isNotEmpty) {
      return '$categoriaNivel1 › $categoriaNivel2';
    }
    return categoriaNivel1 ?? 'Sin categoría';
  }
}
