import 'package:finanzas_ia/models/movimiento_kardex.dart';
import 'package:finanzas_ia/models/producto_inventario.dart';
import 'package:finanzas_ia/models/proveedor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_repository.dart';

void main() {
  group('Fase 8 - Modelos y Lógica de Inventario Enriquecido y Proveedores', () {
    test('Proveedor serializa y deserializa correctamente', () {
      final json = {
        'id': 'prov-123',
        'nombre': 'Distribuidora Central',
        'contacto': 'Carlos Gómez',
        'telefono': '55551234',
        'direccion': 'Zona 3, Quetzaltenango',
        'dias_visita': 'Martes y Jueves',
        'notas': 'Descuento por volumen',
        'activo': true,
      };

      final proveedor = Proveedor.fromJson(json);

      expect(proveedor.id, 'prov-123');
      expect(proveedor.nombre, 'Distribuidora Central');
      expect(proveedor.contacto, 'Carlos Gómez');
      expect(proveedor.telefono, '55551234');
      expect(proveedor.diasVisita, 'Martes y Jueves');
      expect(proveedor.activo, isTrue);

      final map = proveedor.toJson();
      expect(map['nombre'], 'Distribuidora Central');
      expect(map['telefono'], '55551234');
    });

    test('ProductoInventario calcula margen porcentual y soporta nuevos atributos', () {
      const producto = ProductoInventario(
        id: 'prod-456',
        nombre: 'Gaseosa Cola 600ml',
        precioCompra: 3.50,
        precioVenta: 5.00,
        existencias: 24,
        valorTotal: 84.0,
        imagenUrl: 'https://ejemplo.com/gaseosa.jpg',
        codigoBarras: '740100523456',
        categoriaProducto: 'Bebidas',
        unidadMedida: 'unidad',
        costoPromedio: 3.50,
        stockMinimo: 6,
        stockMaximo: 48,
        proveedorId: 'prov-123',
        proveedorNombre: 'Distribuidora Central',
        estado: 'ok',
      );

      expect(producto.id, 'prod-456');
      expect(producto.imagenUrl, 'https://ejemplo.com/gaseosa.jpg');
      expect(producto.categoriaProducto, 'Bebidas');
      expect(producto.codigoBarras, '740100523456');
      expect(producto.stockMaximo, 48);
      expect(producto.proveedorNombre, 'Distribuidora Central');

      // Margen: ((5.0 - 3.5) / 5.0) * 100 = 30.0%
      expect(producto.margenPorcentual, closeTo(30.0, 0.01));
    });

    test('MovimientoKardex parsea fechas, cantidades y motivo de ajuste', () {
      final json = {
        'id': 'kardex-1',
        'tipo_movimiento': 'ajuste',
        'cantidad': -2.0,
        'costo_unitario': 5.0,
        'existencia_resultante': 10.0,
        'costo_promedio_resultante': 5.0,
        'motivo': 'Producto dañado / vencido',
        'fecha': '2026-09-02',
        'creado_en': '2026-09-02T10:00:00Z',
      };

      final mov = MovimientoKardex.fromJson(json);

      expect(mov.id, 'kardex-1');
      expect(mov.tipoMovimiento, 'ajuste');
      expect(mov.cantidad, -2.0);
      expect(mov.motivo, 'Producto dañado / vencido');
      expect(mov.existenciaResultante, 10.0);
    });

    test('FakeRepository permite CRUD completo de proveedores', () async {
      final repo = FakeRepository();

      final creado = await repo.crearProveedor(
        nombre: 'Don Pedro Frutas',
        telefono: '50001111',
        diasVisita: 'Lunes',
      );

      expect(creado, isNotNull);
      expect(creado!.nombre, 'Don Pedro Frutas');

      final lista = await repo.obtenerProveedores();
      expect(lista.length, 1);
      expect(lista.first.nombre, 'Don Pedro Frutas');

      final actualizado = await repo.actualizarProveedor(
        Proveedor(
          id: creado.id,
          nombre: 'Don Pedro Frutas y Verduras',
          telefono: '50002222',
        ),
      );
      expect(actualizado, isTrue);

      final listaActualizada = await repo.obtenerProveedores();
      expect(listaActualizada.first.nombre, 'Don Pedro Frutas y Verduras');
      expect(listaActualizada.first.telefono, '50002222');

      final eliminado = await repo.eliminarProveedor(creado.id);
      expect(eliminado, isTrue);

      final listaFinal = await repo.obtenerProveedores();
      expect(listaFinal, isEmpty);
    });

    test('FakeRepository permite renombrar producto por ID y registrar ajustes con motivo', () async {
      final repo = FakeRepository();

      final okUpdate = await repo.actualizarProductoPorId(
        productoId: 'prod-abc',
        nuevoNombre: 'Nuevo Nombre de Producto',
        precioVenta: 15.0,
        categoriaProducto: 'Abarrotes',
      );

      expect(okUpdate, isTrue);
      expect(repo.lastProductoId, 'prod-abc');
      expect(repo.lastNombreActualizado, 'Nuevo Nombre de Producto');
      expect(repo.lastPrecioVentaActualizado, 15.0);

      final okAjuste = await repo.ajustarInventarioConMotivo(
        productoId: 'prod-abc',
        cantidadObjetivo: 25.0,
        motivo: 'Merma o autoconsumo',
      );

      expect(okAjuste, isTrue);
      expect(repo.lastCantidadObjetivo, 25.0);
      expect(repo.ajustesInventario, 1);
    });
  });
}
