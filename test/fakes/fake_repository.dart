import 'package:finanzas_ia/models/flujo_caja.dart';
import 'package:finanzas_ia/models/listado_transaccion.dart';
import 'package:finanzas_ia/models/producto_inventario.dart';
import 'package:finanzas_ia/models/resumen_analisis.dart';
import 'package:finanzas_ia/models/resumen_ganancias.dart';
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
}
