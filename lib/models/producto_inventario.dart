class ProductoInventario {
  const ProductoInventario({
    required this.nombre,
    required this.precioCompra,
    required this.precioVenta,
    required this.existencias,
    required this.valorTotal,
  });

  final String nombre;
  final double precioCompra;
  final double precioVenta;
  final double existencias;
  final double valorTotal;
}
