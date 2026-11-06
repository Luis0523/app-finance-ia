import 'producto_inventario.dart';
import 'proveedor.dart';

class ItemSugerenciaProducto {
  const ItemSugerenciaProducto({
    required this.producto,
    required this.existenciasActuales,
    required this.stockMinimo,
    required this.cantidadSugerida,
    required this.costoUnitario,
    required this.costoTotalEstimado,
  });

  final ProductoInventario producto;
  final double existenciasActuales;
  final double stockMinimo;
  final double cantidadSugerida;
  final double costoUnitario;
  final double costoTotalEstimado;
}

class SugerenciaPedidoProveedor {
  const SugerenciaPedidoProveedor({
    required this.proveedor,
    required this.productos,
    required this.costoTotalEstimado,
    required this.diaVisitaTexto,
    required this.esVisitaHoy,
    required this.esVisitaManana,
  });

  final Proveedor proveedor;
  final List<ItemSugerenciaProducto> productos;
  final double costoTotalEstimado;
  final String diaVisitaTexto;
  final bool esVisitaHoy;
  final bool esVisitaManana;

  int get totalArticulos => productos.length;
}
