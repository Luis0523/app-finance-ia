import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_ia/models/cuenta_por_cobrar.dart';
import 'package:finanzas_ia/models/abono_cuenta_cobrar.dart';
import 'package:finanzas_ia/models/producto_inventario.dart';
import 'package:finanzas_ia/models/sugerencia_pedido_proveedor.dart';
import 'package:finanzas_ia/models/proveedor.dart';
import 'fakes/fake_repository.dart';

void main() {
  group('Modelos - Cuentas por Cobrar y Fiados', () {
    test('CuentaPorCobrar calcula saldo y estado pagado correctamente', () {
      final cuenta = CuentaPorCobrar(
        id: 'c1',
        clienteNombre: 'Dona Carmen',
        montoTotal: 100.0,
        saldoPendiente: 25.0,
        estado: 'pendiente',
        fecha: DateTime.now().subtract(const Duration(days: 5)),
        creadoEn: DateTime.now(),
      );

      expect(cuenta.totalAbonado, 75.0);
      expect(cuenta.estaPagado, false);
      expect(cuenta.diasDeuda, greaterThanOrEqualTo(5));
    });

    test('CuentaPorCobrar fromMap y toMap funcionan simétricamente', () {
      final map = {
        'id': 'c2',
        'cliente_nombre': 'Don Carlos',
        'cliente_telefono': '5555-1234',
        'monto_total': 50.0,
        'saldo_pendiente': 0.0,
        'descripcion': '2 gaseosas fiadas',
        'estado': 'pagado',
        'fecha': '2026-09-01T10:00:00.000Z',
        'creado_en': '2026-09-01T10:00:00.000Z',
      };

      final cuenta = CuentaPorCobrar.fromMap(map);
      expect(cuenta.clienteNombre, 'Don Carlos');
      expect(cuenta.clienteTelefono, '5555-1234');
      expect(cuenta.estaPagado, true);
      expect(cuenta.totalAbonado, 50.0);

      final toMap = cuenta.toMap();
      expect(toMap['cliente_nombre'], 'Don Carlos');
      expect(toMap['saldo_pendiente'], 0.0);
    });

    test('AbonoCuentaCobrar fromMap maneja datos correctamente', () {
      final map = {
        'id': 'a1',
        'cuenta_cobrar_id': 'c1',
        'monto': 35.0,
        'metodo_pago': 'Efectivo',
        'fecha': '2026-09-02T12:00:00.000Z',
        'notas': 'Abono quincenal',
        'creado_en': '2026-09-02T12:00:00.000Z',
      };

      final abono = AbonoCuentaCobrar.fromMap(map);
      expect(abono.monto, 35.0);
      expect(abono.metodoPago, 'Efectivo');
      expect(abono.notas, 'Abono quincenal');
    });

    test('SugerenciaPedidoProveedor calcula articulos y costo total', () {
      const proveedor = Proveedor(
        id: 'prov1',
        nombre: 'Distribuidora Central',
        diasVisita: 'Lunes, Miércoles',
      );

      const producto = ProductoInventario(
        id: 'prod1',
        nombre: 'Aceite Ideal 1L',
        existencias: 2.0,
        stockMinimo: 10.0,
        stockMaximo: 24.0,
        precioCompra: 12.50,
        precioVenta: 15.0,
        valorTotal: 25.0,
      );

      const item = ItemSugerenciaProducto(
        producto: producto,
        existenciasActuales: 2.0,
        stockMinimo: 10.0,
        cantidadSugerida: 22.0,
        costoUnitario: 12.50,
        costoTotalEstimado: 275.0,
      );

      const sugerencia = SugerenciaPedidoProveedor(
        proveedor: proveedor,
        productos: [item],
        costoTotalEstimado: 275.0,
        diaVisitaTexto: 'Hoy',
        esVisitaHoy: true,
        esVisitaManana: false,
      );

      expect(sugerencia.costoTotalEstimado, 275.0);
      expect(sugerencia.totalArticulos, 1);
      expect(sugerencia.esVisitaHoy, true);
    });
  });

  group('FakeRepository - Cuentas por Cobrar, Abonos y Gastos', () {
    late FakeRepository repo;

    setUp(() {
      repo = FakeRepository();
    });

    test('registrarFiado agrega la cuenta y permite consultarla', () async {
      final cuenta = await repo.registrarFiado(
        clienteNombre: 'Dona Gloria',
        monto: 85.50,
        descripcion: 'Abarrotes fin de mes',
        clienteTelefono: '4444-9999',
      );

      expect(cuenta, isNotNull);
      expect(cuenta!.clienteNombre, 'Dona Gloria');
      expect(cuenta.montoTotal, 85.50);
      expect(cuenta.saldoPendiente, 85.50);
      expect(cuenta.estado, 'pendiente');

      final todas = await repo.obtenerCuentasPorCobrar();
      expect(todas.any((c) => c.clienteNombre == 'Dona Gloria'), isTrue);
    });

    test('registrarAbonoFiado actualiza saldo y liquida si cubre el total', () async {
      final cuenta = await repo.registrarFiado(
        clienteNombre: 'Mario B.',
        monto: 100.0,
      );
      expect(cuenta, isNotNull);

      // Abono parcial
      final abonoOk1 = await repo.registrarAbonoFiado(
        cuentaId: cuenta!.id,
        monto: 40.0,
        metodoPago: 'Efectivo',
      );
      expect(abonoOk1, isTrue);

      var cuentas = await repo.obtenerCuentasPorCobrar();
      var cActualizada = cuentas.firstWhere((c) => c.id == cuenta.id);
      expect(cActualizada.saldoPendiente, 60.0);
      expect(cActualizada.estado, 'parcial');

      // Abono que salda la deuda
      final abonoOk2 = await repo.registrarAbonoFiado(
        cuentaId: cuenta.id,
        monto: 60.0,
        metodoPago: 'Efectivo',
      );
      expect(abonoOk2, isTrue);

      cuentas = await repo.obtenerCuentasPorCobrar();
      cActualizada = cuentas.firstWhere((c) => c.id == cuenta.id);
      expect(cActualizada.saldoPendiente, 0.0);
      expect(cActualizada.estado, 'pagado');
      expect(cActualizada.estaPagado, isTrue);
    });

    test('registrarGastoManual incrementa contador y retorna ID', () async {
      final gastoId = await repo.registrarGastoManual(
        monto: 150.0,
        categoriaNivel1: 'Gastos operativos',
        descripcion: 'Pago de Recibo de Luz Electrica',
        metodoPago: 'Efectivo',
      );

      expect(gastoId, isNotNull);
      expect(repo.gastosManualesRegistrados, 1);
      expect(repo.transacciones, 1);
    });

    test('obtenerSugerenciasPedidosProveedores retorna la lista configurada', () async {
      const prov = Proveedor(
        id: 'prov-cc',
        nombre: 'Cerveceria Centro Americana',
        diasVisita: 'Lunes, Jueves',
      );

      repo.sugerenciasPedidos = [
        const SugerenciaPedidoProveedor(
          proveedor: prov,
          productos: [],
          costoTotalEstimado: 500.0,
          diaVisitaTexto: 'Manana',
          esVisitaHoy: false,
          esVisitaManana: true,
        ),
      ];

      final sugerencias = await repo.obtenerSugerenciasPedidosProveedores();
      expect(sugerencias.length, 1);
      expect(sugerencias.first.proveedor.nombre, 'Cerveceria Centro Americana');
      expect(sugerencias.first.esVisitaManana, isTrue);
    });
  });
}
