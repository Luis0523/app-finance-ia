class TotalesMes {
  const TotalesMes({
    required this.ingresos,
    required this.egresos,
    required this.cantidadIngresos,
    required this.cantidadEgresos,
  });

  final double ingresos;
  final double egresos;
  final int cantidadIngresos;
  final int cantidadEgresos;

  double get balance => ingresos - egresos;
}
