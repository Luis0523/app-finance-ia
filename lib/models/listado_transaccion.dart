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
    final nivel2 = categoriaNivel2?.trim();
    if (nivel2 != null && nivel2.isNotEmpty) {
      return nivel2;
    }

    final nivel1 = categoriaNivel1?.trim();
    if (nivel1 != null && nivel1.isNotEmpty) return nivel1;

    return 'Sin categoría';
  }
}
