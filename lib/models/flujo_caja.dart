class FlujoDia {
  const FlujoDia({
    required this.fecha,
    required this.ingresos,
    required this.egresos,
    required this.balance,
  });

  final DateTime fecha;
  final double ingresos;
  final double egresos;
  final double balance;
}
