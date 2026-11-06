class ProductoInventario {
  const ProductoInventario({
    this.id,
    required this.nombre,
    required this.precioCompra,
    required this.precioVenta,
    required this.existencias,
    required this.valorTotal,
    this.imagenUrl,
    this.codigoBarras,
    this.categoriaProducto,
    this.unidadMedida = 'unidad',
    this.costoPromedio,
    this.utilidadUnitaria,
    this.stockMinimo,
    this.stockMaximo,
    this.proveedorId,
    this.proveedorNombre,
    this.estado,
  });

  final String? id;
  final String nombre;
  final double precioCompra;
  final double precioVenta;
  final double existencias;
  final double valorTotal;
  final String? imagenUrl;
  final String? codigoBarras;
  final String? categoriaProducto;
  final String unidadMedida;
  final double? costoPromedio;
  final double? utilidadUnitaria;
  final double? stockMinimo;
  final double? stockMaximo;
  final String? proveedorId;
  final String? proveedorNombre;
  final String? estado;

  double get margenPorcentual {
    if (precioVenta <= 0) return 0;
    final costo = costoPromedio ?? precioCompra;
    if (costo <= 0) return 100;
    return ((precioVenta - costo) / precioVenta) * 100;
  }
}
