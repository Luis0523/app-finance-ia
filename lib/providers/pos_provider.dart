import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/item_venta_pos.dart';
import '../models/producto_inventario.dart';

class PosCarritoState {
  const PosCarritoState({this.items = const []});

  final List<ItemVentaPos> items;

  double get totalVenta => double.parse(
        items.fold<double>(0, (sum, item) => sum + item.subtotal).toStringAsFixed(2),
      );

  int get totalArticulos => items.fold<int>(
        0,
        (sum, item) => sum + item.cantidad.toInt(),
      );

  int get lineasContador => items.length;

  bool get estaVacio => items.isEmpty;

  PosCarritoState copyWith({List<ItemVentaPos>? items}) {
    return PosCarritoState(items: items ?? this.items);
  }
}

class PosNotifier extends StateNotifier<PosCarritoState> {
  PosNotifier() : super(const PosCarritoState());

  String _getKey(ProductoInventario p) {
    if (p.id != null && p.id!.isNotEmpty) return p.id!;
    return p.nombre.toLowerCase().trim();
  }

  void agregarProducto(ProductoInventario producto, [double cantidad = 1]) {
    final key = _getKey(producto);
    final index = state.items.indexWhere((it) => _getKey(it.producto) == key);

    if (index != -1) {
      final actual = state.items[index];
      final actualizada = actual.copyWith(cantidad: actual.cantidad + cantidad);
      final nuevaLista = List<ItemVentaPos>.from(state.items);
      nuevaLista[index] = actualizada;
      state = state.copyWith(items: nuevaLista);
    } else {
      final nuevoItem = ItemVentaPos(
        producto: producto,
        cantidad: cantidad,
        precioUnitario: producto.precioVenta,
      );
      state = state.copyWith(items: [...state.items, nuevoItem]);
    }
  }

  /// Retorna el [ProductoInventario] si se encontró y agregó, o `null` si no existe con ese código.
  ProductoInventario? agregarPorCodigoBarras(
    String codigo,
    List<ProductoInventario> catalogo,
  ) {
    final limpio = codigo.trim();
    if (limpio.isEmpty) return null;

    final index = catalogo.indexWhere(
      (p) => p.codigoBarras != null && p.codigoBarras!.trim() == limpio,
    );

    if (index == -1) return null;

    final encontrado = catalogo[index];
    agregarProducto(encontrado, 1);
    return encontrado;
  }

  void incrementarCantidad(String productoKey) {
    final index = state.items.indexWhere((it) => _getKey(it.producto) == productoKey);
    if (index == -1) return;

    final actual = state.items[index];
    final nuevaLista = List<ItemVentaPos>.from(state.items);
    nuevaLista[index] = actual.copyWith(cantidad: actual.cantidad + 1);
    state = state.copyWith(items: nuevaLista);
  }

  void decrementarCantidad(String productoKey) {
    final index = state.items.indexWhere((it) => _getKey(it.producto) == productoKey);
    if (index == -1) return;

    final actual = state.items[index];
    final nuevaLista = List<ItemVentaPos>.from(state.items);

    if (actual.cantidad > 1) {
      nuevaLista[index] = actual.copyWith(cantidad: actual.cantidad - 1);
    } else {
      nuevaLista.removeAt(index);
    }
    state = state.copyWith(items: nuevaLista);
  }

  void actualizarCantidad(String productoKey, double nuevaCantidad) {
    final index = state.items.indexWhere((it) => _getKey(it.producto) == productoKey);
    if (index == -1) return;

    final nuevaLista = List<ItemVentaPos>.from(state.items);
    if (nuevaCantidad <= 0) {
      nuevaLista.removeAt(index);
    } else {
      nuevaLista[index] = nuevaLista[index].copyWith(cantidad: nuevaCantidad);
    }
    state = state.copyWith(items: nuevaLista);
  }

  void actualizarPrecioUnitario(String productoKey, double nuevoPrecio) {
    final index = state.items.indexWhere((it) => _getKey(it.producto) == productoKey);
    if (index == -1) return;

    final nuevaLista = List<ItemVentaPos>.from(state.items);
    nuevaLista[index] = nuevaLista[index].copyWith(precioUnitario: nuevoPrecio);
    state = state.copyWith(items: nuevaLista);
  }

  void eliminarItem(String productoKey) {
    final nuevaLista =
        state.items.where((it) => _getKey(it.producto) != productoKey).toList();
    state = state.copyWith(items: nuevaLista);
  }

  void limpiarCarrito() {
    state = const PosCarritoState();
  }
}

final posProvider = StateNotifierProvider<PosNotifier, PosCarritoState>((ref) {
  return PosNotifier();
});
