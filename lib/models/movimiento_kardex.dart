class MovimientoKardex {
  const MovimientoKardex({
    required this.id,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.costoUnitario,
    required this.existenciaResultante,
    required this.costoPromedioResultante,
    this.motivo,
    required this.fecha,
    this.creadoEn,
  });

  final String id;
  final String tipoMovimiento;
  final double cantidad;
  final double costoUnitario;
  final double existenciaResultante;
  final double costoPromedioResultante;
  final String? motivo;
  final DateTime fecha;
  final DateTime? creadoEn;

  factory MovimientoKardex.fromJson(Map<String, dynamic> json) {
    return MovimientoKardex(
      id: json['id']?.toString() ?? '',
      tipoMovimiento: json['tipo_movimiento']?.toString() ?? '',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
      costoUnitario: (json['costo_unitario'] as num?)?.toDouble() ?? 0,
      existenciaResultante: (json['existencia_resultante'] as num?)?.toDouble() ?? 0,
      costoPromedioResultante: (json['costo_promedio_resultante'] as num?)?.toDouble() ?? 0,
      motivo: json['motivo']?.toString(),
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
      creadoEn: DateTime.tryParse(json['creado_en']?.toString() ?? ''),
    );
  }
}
