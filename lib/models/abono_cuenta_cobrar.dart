class AbonoCuentaCobrar {
  const AbonoCuentaCobrar({
    required this.id,
    required this.cuentaCobrarId,
    required this.monto,
    required this.metodoPago,
    required this.fecha,
    this.notas,
    required this.creadoEn,
  });

  final String id;
  final String cuentaCobrarId;
  final double monto;
  final String metodoPago;
  final DateTime fecha;
  final String? notas;
  final DateTime creadoEn;

  factory AbonoCuentaCobrar.fromMap(Map<String, dynamic> map) {
    return AbonoCuentaCobrar(
      id: map['id']?.toString() ?? '',
      cuentaCobrarId: map['cuenta_cobrar_id']?.toString() ?? '',
      monto: _toDouble(map['monto']),
      metodoPago: map['metodo_pago']?.toString() ?? 'efectivo',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha'].toString()) : DateTime.now(),
      notas: map['notas']?.toString(),
      creadoEn: map['creado_en'] != null
          ? DateTime.parse(map['creado_en'].toString())
          : DateTime.now(),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}
