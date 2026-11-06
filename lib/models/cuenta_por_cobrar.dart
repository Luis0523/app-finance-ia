class CuentaPorCobrar {
  const CuentaPorCobrar({
    required this.id,
    required this.clienteNombre,
    this.clienteTelefono,
    required this.montoTotal,
    required this.saldoPendiente,
    this.descripcion,
    required this.estado,
    required this.fecha,
    this.fechaLimite,
    this.transaccionId,
    required this.creadoEn,
  });

  final String id;
  final String clienteNombre;
  final String? clienteTelefono;
  final double montoTotal;
  final double saldoPendiente;
  final String? descripcion;
  /// 'pendiente', 'parcial', 'pagado'
  final String estado;
  final DateTime fecha;
  final DateTime? fechaLimite;
  final String? transaccionId;
  final DateTime creadoEn;

  double get totalAbonado => double.parse((montoTotal - saldoPendiente).toStringAsFixed(2));
  bool get estaPagado => saldoPendiente <= 0;
  bool get tieneAbonos => totalAbonado > 0 && !estaPagado;

  int get diasDeuda {
    final diff = DateTime.now().difference(fecha).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory CuentaPorCobrar.fromMap(Map<String, dynamic> map) {
    return CuentaPorCobrar(
      id: map['id']?.toString() ?? '',
      clienteNombre: map['cliente_nombre']?.toString() ?? 'Cliente',
      clienteTelefono: map['cliente_telefono']?.toString(),
      montoTotal: _toDouble(map['monto_total']),
      saldoPendiente: _toDouble(map['saldo_pendiente']),
      descripcion: map['descripcion']?.toString(),
      estado: map['estado']?.toString() ?? 'pendiente',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha'].toString()) : DateTime.now(),
      fechaLimite: map['fecha_limite'] != null
          ? DateTime.tryParse(map['fecha_limite'].toString())
          : null,
      transaccionId: map['transaccion_id']?.toString(),
      creadoEn: map['creado_en'] != null
          ? DateTime.parse(map['creado_en'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'cliente_nombre': clienteNombre,
    if (clienteTelefono != null) 'cliente_telefono': clienteTelefono,
    'monto_total': montoTotal,
    'saldo_pendiente': saldoPendiente,
    if (descripcion != null) 'descripcion': descripcion,
    'estado': estado,
    'fecha': fecha.toIso8601String().substring(0, 10),
    if (fechaLimite != null)
      'fecha_limite': fechaLimite!.toIso8601String().substring(0, 10),
    if (transaccionId != null) 'transaccion_id': transaccionId,
  };

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}
