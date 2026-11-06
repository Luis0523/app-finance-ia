import 'producto_inventario.dart';

class ItemVentaPos {
  const ItemVentaPos({
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
  });

  final ProductoInventario producto;
  final double cantidad;
  final double precioUnitario;

  double get subtotal => double.parse((cantidad * precioUnitario).toStringAsFixed(2));

  ItemVentaPos copyWith({
    ProductoInventario? producto,
    double? cantidad,
    double? precioUnitario,
  }) {
    return ItemVentaPos(
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
    );
  }
}
