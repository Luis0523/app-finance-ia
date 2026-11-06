import 'package:finanzas_ia/models/item_venta_pos.dart';
import 'package:finanzas_ia/models/producto_inventario.dart';
import 'package:finanzas_ia/providers/pos_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_repository.dart';

void main() {
  group('Módulo POS - Pruebas Unitarias', () {
    const p1 = ProductoInventario(
      id: 'prod-1',
      nombre: 'Coca Cola 600ml',
      precioCompra: 3.50,
      precioVenta: 5.00,
      existencias: 20,
      valorTotal: 70.0,
      codigoBarras: '740100523456',
    );

    const p2 = ProductoInventario(
      id: 'prod-2',
      nombre: 'Galletas Chocochips',
      precioCompra: 1.50,
      precioVenta: 2.50,
      existencias: 15,
      valorTotal: 22.5,
      codigoBarras: '740100999999',
    );

    test('ItemVentaPos calcula subtotal con precisión decimal', () {
      const item = ItemVentaPos(
        producto: p1,
        cantidad: 3,
        precioUnitario: 5.00,
      );

      expect(item.subtotal, 15.00);

      final modificado = item.copyWith(cantidad: 2.5);
      expect(modificado.subtotal, 12.50);
    });

    test('PosNotifier gestiona agregados, incrementos y decrementos', () {
      final notifier = PosNotifier();

      expect(notifier.state.estaVacio, isTrue);

      // Agregar p1
      notifier.agregarProducto(p1, 2);
      expect(notifier.state.items.length, 1);
      expect(notifier.state.totalArticulos, 2);
      expect(notifier.state.totalVenta, 10.00);

      // Agregar p1 otra vez (debe acumular en la misma línea)
      notifier.agregarProducto(p1, 1);
      expect(notifier.state.items.length, 1);
      expect(notifier.state.totalArticulos, 3);
      expect(notifier.state.totalVenta, 15.00);

      // Agregar p2
      notifier.agregarProducto(p2, 2);
      expect(notifier.state.items.length, 2);
      expect(notifier.state.totalArticulos, 5);
      expect(notifier.state.totalVenta, 20.00); // 15 + 5 = 20

      // Decrementar p1
      notifier.decrementarCantidad('prod-1');
      expect(notifier.state.totalArticulos, 4);
      expect(notifier.state.totalVenta, 15.00);

      // Incrementar p2
      notifier.incrementarCantidad('prod-2');
      expect(notifier.state.totalArticulos, 5);
      expect(notifier.state.totalVenta, 17.50);

      // Limpiar ticket
      notifier.limpiarCarrito();
      expect(notifier.state.estaVacio, isTrue);
      expect(notifier.state.totalVenta, 0.0);
    });

    test('PosNotifier encuentra y agrega producto por código de barras', () {
      final notifier = PosNotifier();
      final catalogo = [p1, p2];

      final encontrado = notifier.agregarPorCodigoBarras('740100523456', catalogo);
      expect(encontrado, isNotNull);
      expect(encontrado!.nombre, 'Coca Cola 600ml');
      expect(notifier.state.totalArticulos, 1);
      expect(notifier.state.totalVenta, 5.00);

      final noExiste = notifier.agregarPorCodigoBarras('000000000000', catalogo);
      expect(noExiste, isNull);
      expect(notifier.state.totalArticulos, 1); // No incrementa
    });

    test('FakeRepository procesa venta POS y actualiza contador de transacciones', () async {
      final repo = FakeRepository();

      final items = [
        const ItemVentaPos(producto: p1, cantidad: 2, precioUnitario: 5.0),
        const ItemVentaPos(producto: p2, cantidad: 1, precioUnitario: 2.5),
      ];

      final ok = await repo.registrarVentaPos(
        items: items,
        metodoPago: 'efectivo',
      );

      expect(ok, isTrue);
      expect(repo.ventasPosRegistradas, 1);
      expect(repo.ultimosItemsPos.length, 2);
      expect(repo.ultimoMetodoPagoPos, 'efectivo');
      expect(repo.transacciones, 2);
    });
  });
}
