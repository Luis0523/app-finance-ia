class ResumenCategoria {
  const ResumenCategoria({
    required this.categoriaNivel1,
    required this.categoriaNivel2,
    required this.tipo,
    required this.total,
    required this.cantidad,
  });

  final String categoriaNivel1;
  final String categoriaNivel2;
  final String tipo;
  final double total;
  final int cantidad;

  String get nombre {
    return categoriaNivel2.isNotEmpty
        ? '$categoriaNivel1 › $categoriaNivel2'
        : categoriaNivel1;
  }
}

class ResumenAnalisis {
  const ResumenAnalisis({
    required this.ingresos,
    required this.egresos,
    required this.cantidadIngresos,
    required this.cantidadEgresos,
    required this.porCategoria,
  });

  final double ingresos;
  final double egresos;
  final int cantidadIngresos;
  final int cantidadEgresos;
  final List<ResumenCategoria> porCategoria;

  double get balance => ingresos - egresos;

  factory ResumenAnalisis.vacio() {
    return const ResumenAnalisis(
      ingresos: 0,
      egresos: 0,
      cantidadIngresos: 0,
      cantidadEgresos: 0,
      porCategoria: [],
    );
  }
}
