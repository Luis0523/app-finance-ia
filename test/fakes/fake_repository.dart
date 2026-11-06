import 'package:finanzas_ia/models/abono_cuenta_cobrar.dart';
import 'package:finanzas_ia/models/cuenta_por_cobrar.dart';
import 'package:finanzas_ia/models/flujo_caja.dart';
import 'package:finanzas_ia/models/item_venta_pos.dart';
import 'package:finanzas_ia/models/listado_transaccion.dart';
import 'package:finanzas_ia/models/movimiento_kardex.dart';
import 'package:finanzas_ia/models/producto_inventario.dart';
import 'package:finanzas_ia/models/proveedor.dart';
import 'package:finanzas_ia/models/resumen_analisis.dart';
import 'package:finanzas_ia/models/resumen_ganancias.dart';
import 'package:finanzas_ia/models/sugerencia_pedido_proveedor.dart';
import 'package:finanzas_ia/models/totales_mes.dart';
import 'package:finanzas_ia/models/ultima_transaccion.dart';
import 'package:finanzas_ia/services/supabase_repository.dart';

class FakeRepository implements FinanzasRepository {
  bool failOnPersist = false;
  Object? errorEnInsertar;
  int categoriaBusquedas = 0;
  int transacciones = 0;
  int conversaciones = 0;
  int conversacionesActualizadas = 0;
  int totalesConsultas = 0;
  int resumenConsultas = 0;
  int gananciasConsultas = 0;
  int ultimaConsultas = 0;
  int listadoConsultas = 0;
  int flujoConsultas = 0;
  int inventarioConsultas = 0;
  int productosCreados = 0;
  int comprasRegistradas = 0;
  int productosActualizados = 0;
  int ajustesInventario = 0;
  String? lastNombreActualizado;
  double? lastPrecioVentaActualizado;
  double? lastStockMinimoActualizado;
  double? lastCantidadObjetivo;
  bool actualizarProductoResult = true;
  bool ajustarInventarioResult = true;
  String? lastCategoriaId;
  String? lastTransaccionId;
  String? lastConversacionId;
  String? ultimoTipoListado;
  String? lastDescripcionOriginal;
  String? lastDescripcionNormalizada;
  String? lastProductoInventario;
  double? lastCantidadInventario;
  String? lastTransaccionInventarioId;
  String? lastProductoId;
  double? lastCostoUnitarioCompra;
  TotalesMes totalesMes = const TotalesMes(
    ingresos: 500,
    egresos: 300,
    cantidadIngresos: 2,
    cantidadEgresos: 1,
  );
  ResumenAnalisis resumenAnalisis = const ResumenAnalisis(
    ingresos: 500,
    egresos: 300,
    cantidadIngresos: 2,
    cantidadEgresos: 1,
    porCategoria: [
      ResumenCategoria(
        categoriaNivel1: 'Ingresos',
        categoriaNivel2: 'Venta de producto',
        tipo: 'ingreso',
        total: 500,
        cantidad: 2,
      ),
      ResumenCategoria(
        categoriaNivel1: 'Gastos operativos',
        categoriaNivel2: 'Renta',
        tipo: 'egreso',
        total: 300,
        cantidad: 1,
      ),
    ],
  );
  UltimaTransaccion? ultima = UltimaTransaccion(
    monto: 150,
    tipo: 'egreso',
    fecha: DateTime(2026, 8, 20),
    categoriaNivel1: 'Gastos operativos',
    categoriaNivel2: 'Servicios públicos',
  );
  List<ListadoTransaccion> listado = [
    ListadoTransaccion(
      fecha: DateTime(2026, 8, 22),
      tipo: 'ingreso',
      monto: 200,
      categoriaNivel1: 'Ingresos',
      categoriaNivel2: 'Venta de producto',
    ),
    ListadoTransaccion(
      fecha: DateTime(2026, 8, 21),
      tipo: 'egreso',
      monto: 150,
      categoriaNivel1: 'Gastos operativos',
      categoriaNivel2: 'Servicios públicos',
    ),
  ];
  List<FlujoDia> flujo = [
    FlujoDia(
      fecha: DateTime(2026, 8, 22),
      ingresos: 500,
      egresos: 200,
      balance: 300,
    ),
  ];
  List<ProductoInventario> productos = const [
    ProductoInventario(
      nombre: 'Fruta (caja)',
      precioCompra: 80,
      precioVenta: 120,
      existencias: 10,
      costoPromedio: 80,
      utilidadUnitaria: 40,
      valorTotal: 800,
      stockMinimo: 2,
      estado: 'ok',
    ),
  ];
  ResumenGanancias resumenGanancias = const ResumenGanancias(
    ingresos: 1400,
    costoVentas: 800,
    utilidad: 600,
    cantidadVentas: 3,
    margen: 0.43,
  );

  @override
  Future<String> buscarOCrearCategoriaNivel2({
    required String categoriaNivel1,
    required String categoriaNivel2,
    required String tipo,
  }) async {
    categoriaBusquedas++;
    lastCategoriaId = 'categoria-$categoriaBusquedas';
    return lastCategoriaId!;
  }

  @override
  Future<String> insertarTransaccion({
    required String categoriaId,
    required double monto,
    required String tipo,
    required String descripcionOriginal,
    required String descripcionNormalizada,
    required String origen,
    required double confianza,
    double? cantidad,
    double? precioUnitario,
    String? productoId,
  }) async {
    if (errorEnInsertar != null) throw errorEnInsertar!;
    if (failOnPersist) throw PersistException('error simulado de persistencia');
    transacciones++;
    lastTransaccionId = 'transaccion-$transacciones';
    lastDescripcionOriginal = descripcionOriginal;
    lastDescripcionNormalizada = descripcionNormalizada;
    return lastTransaccionId!;
  }

  @override
  Future<String> insertarConversacion({
    required String mensajeUsuario,
    required String intencion,
    required String? respuestaSistema,
  }) async {
    conversaciones++;
    lastConversacionId = 'conversacion-$conversaciones';
    return lastConversacionId!;
  }

  @override
  Future<void> actualizarTransaccionEnConversacion({
    required String conversacionId,
    required String transaccionId,
  }) async {
    conversacionesActualizadas++;
  }

  @override
  Future<TotalesMes> obtenerTotalesMes() async {
    totalesConsultas++;
    return totalesMes;
  }

  @override
  Future<ResumenAnalisis> obtenerResumenAnalisis() async {
    resumenConsultas++;
    return resumenAnalisis;
  }

  @override
  Future<UltimaTransaccion?> ultimaTransaccion({String? tipo}) async {
    ultimaConsultas++;
    return ultima;
  }

  @override
  Future<List<ListadoTransaccion>> listadoTransacciones({
    String? tipo,
    int limite = 50,
  }) async {
    listadoConsultas++;
    ultimoTipoListado = tipo;
    if (tipo == null) return listado;
    return listado.where((t) => t.tipo == tipo).toList();
  }

  @override
  Future<List<FlujoDia>> flujoCaja() async {
    flujoConsultas++;
    return flujo;
  }

  @override
  Future<ResumenGanancias> obtenerResumenGanancias() async {
    gananciasConsultas++;
    return resumenGanancias;
  }

  @override
  Future<List<ProductoInventario>> inventario() async {
    inventarioConsultas++;
    return productos;
  }

  @override
  Future<String?> buscarOCrearProducto({
    required String nombre,
    double? precioCompra,
    double? precioVenta,
    String unidadMedida = 'unidad',
    String tipoProducto = 'reventa',
  }) async {
    productosCreados++;
    lastProductoInventario = nombre;
    lastProductoId = 'producto-$productosCreados';
    return lastProductoId;
  }

  @override
  Future<String?> registrarCompra({
    required String productoId,
    required double cantidad,
    required double costoUnitario,
    String? proveedor,
    String? transaccionId,
  }) async {
    comprasRegistradas++;
    lastProductoId = productoId;
    lastCantidadInventario = cantidad;
    lastCostoUnitarioCompra = costoUnitario;
    lastTransaccionInventarioId = transaccionId;
    return 'compra-$comprasRegistradas';
  }

  @override
  Future<bool> actualizarProducto({
    required String nombre,
    double? precioVenta,
    double? precioCompra,
    double? stockMinimo,
  }) async {
    productosActualizados++;
    lastNombreActualizado = nombre;
    lastPrecioVentaActualizado = precioVenta;
    lastStockMinimoActualizado = stockMinimo;
    return actualizarProductoResult;
  }

  @override
  Future<bool> ajustarInventario({
    required String nombre,
    required double cantidadObjetivo,
  }) async {
    ajustesInventario++;
    lastNombreActualizado = nombre;
    lastCantidadObjetivo = cantidadObjetivo;
    return ajustarInventarioResult;
  }

  List<Proveedor> listaProveedores = [];
  List<MovimientoKardex> listaKardex = [];

  @override
  Future<bool> actualizarProductoPorId({
    required String productoId,
    String? nuevoNombre,
    double? precioVenta,
    double? precioCompra,
    double? stockMinimo,
    double? stockMaximo,
    String? unidadMedida,
    String? categoriaProducto,
    String? codigoBarras,
    String? imagenUrl,
    String? proveedorId,
  }) async {
    productosActualizados++;
    lastProductoId = productoId;
    if (nuevoNombre != null) lastNombreActualizado = nuevoNombre;
    if (precioVenta != null) lastPrecioVentaActualizado = precioVenta;
    if (stockMinimo != null) lastStockMinimoActualizado = stockMinimo;
    return actualizarProductoResult;
  }

  @override
  Future<bool> ajustarInventarioConMotivo({
    required String productoId,
    required double cantidadObjetivo,
    String motivo = 'Ajuste manual',
  }) async {
    ajustesInventario++;
    lastProductoId = productoId;
    lastCantidadObjetivo = cantidadObjetivo;
    return ajustarInventarioResult;
  }

  @override
  Future<List<Proveedor>> obtenerProveedores() async {
    return listaProveedores;
  }

  @override
  Future<Proveedor?> crearProveedor({
    required String nombre,
    String? contacto,
    String? telefono,
    String? direccion,
    String? diasVisita,
    String? notas,
  }) async {
    final p = Proveedor(
      id: 'prov-${listaProveedores.length + 1}',
      nombre: nombre,
      contacto: contacto,
      telefono: telefono,
      direccion: direccion,
      diasVisita: diasVisita,
      notas: notas,
    );
    listaProveedores.add(p);
    return p;
  }

  @override
  Future<bool> actualizarProveedor(Proveedor proveedor) async {
    final idx = listaProveedores.indexWhere((e) => e.id == proveedor.id);
    if (idx != -1) {
      listaProveedores[idx] = proveedor;
      return true;
    }
    return false;
  }

  @override
  Future<bool> eliminarProveedor(String id) async {
    final idx = listaProveedores.indexWhere((e) => e.id == id);
    if (idx != -1) {
      listaProveedores.removeAt(idx);
      return true;
    }
    return false;
  }

  @override
  Future<List<MovimientoKardex>> obtenerKardexProducto({
    required String productoId,
    int limite = 30,
  }) async {
    return listaKardex;
  }

  @override
  Future<String?> subirImagenProducto({
    required List<int> bytes,
    required String extension,
  }) async {
    return 'https://fake-storage.com/prod_123.$extension';
  }

  int ventasPosRegistradas = 0;
  List<ItemVentaPos> ultimosItemsPos = [];
  String? ultimoMetodoPagoPos;

  @override
  Future<bool> registrarVentaPos({
    required List<ItemVentaPos> items,
    required String metodoPago,
    String? notas,
  }) async {
    ventasPosRegistradas++;
    ultimosItemsPos = items;
    ultimoMetodoPagoPos = metodoPago;
    transacciones += items.length;
    return true;
  }

  List<CuentaPorCobrar> cuentasPorCobrar = [];
  List<AbonoCuentaCobrar> abonosRegistrados = [];
  List<SugerenciaPedidoProveedor> sugerenciasPedidos = [];
  int gastosManualesRegistrados = 0;

  @override
  Future<List<CuentaPorCobrar>> obtenerCuentasPorCobrar({String? estado}) async {
    if (estado == null) return cuentasPorCobrar;
    return cuentasPorCobrar.where((c) => c.estado == estado).toList();
  }

  @override
  Future<CuentaPorCobrar?> registrarFiado({
    required String clienteNombre,
    required double monto,
    String? descripcion,
    String? clienteTelefono,
    DateTime? fechaLimite,
    String? transaccionId,
  }) async {
    final cuenta = CuentaPorCobrar(
      id: 'cuenta-${cuentasPorCobrar.length + 1}',
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      montoTotal: monto,
      saldoPendiente: monto,
      descripcion: descripcion,
      estado: 'pendiente',
      fecha: DateTime.now(),
      fechaLimite: fechaLimite,
      transaccionId: transaccionId,
      creadoEn: DateTime.now(),
    );
    cuentasPorCobrar.add(cuenta);
    return cuenta;
  }

  @override
  Future<bool> registrarAbonoFiado({
    required String cuentaId,
    required double monto,
    String metodoPago = 'efectivo',
    String? notas,
  }) async {
    final idx = cuentasPorCobrar.indexWhere((c) => c.id == cuentaId);
    if (idx != -1) {
      final actual = cuentasPorCobrar[idx];
      final nuevoSaldo = (actual.saldoPendiente - monto) < 0 ? 0.0 : (actual.saldoPendiente - monto);
      cuentasPorCobrar[idx] = CuentaPorCobrar(
        id: actual.id,
        clienteNombre: actual.clienteNombre,
        clienteTelefono: actual.clienteTelefono,
        montoTotal: actual.montoTotal,
        saldoPendiente: nuevoSaldo,
        descripcion: actual.descripcion,
        estado: nuevoSaldo <= 0 ? 'pagado' : 'parcial',
        fecha: actual.fecha,
        fechaLimite: actual.fechaLimite,
        transaccionId: actual.transaccionId,
        creadoEn: actual.creadoEn,
      );
    }
    abonosRegistrados.add(AbonoCuentaCobrar(
      id: 'abono-${abonosRegistrados.length + 1}',
      cuentaCobrarId: cuentaId,
      monto: monto,
      metodoPago: metodoPago,
      fecha: DateTime.now(),
      notas: notas,
      creadoEn: DateTime.now(),
    ));
    transacciones++;
    return true;
  }

  @override
  Future<List<SugerenciaPedidoProveedor>> obtenerSugerenciasPedidosProveedores() async {
    return sugerenciasPedidos;
  }

  @override
  Future<String?> registrarGastoManual({
    required double monto,
    required String categoriaNivel1,
    String? categoriaNivel2,
    required String descripcion,
    String? metodoPago,
  }) async {
    gastosManualesRegistrados++;
    transacciones++;
    return 'gasto-$gastosManualesRegistrados';
  }
}
