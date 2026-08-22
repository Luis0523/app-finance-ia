class ProductoInventario {
  const ProductoInventario({
    required this.nombre,
    required this.precioCompra,
    required this.precioVenta,
    required this.existencias,
    required this.valorTotal,
    this.costoPromedio,
    this.utilidadUnitaria,
    this.stockMinimo,
    this.estado,
  });

  final String nombre;
  final double precioCompra;
  final double precioVenta;
  final double existencias;
  final double valorTotal;
  final double? costoPromedio;
  final double? utilidadUnitaria;
  final double? stockMinimo;
  final String? estado;
}
