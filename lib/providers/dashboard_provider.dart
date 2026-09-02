import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flujo_caja.dart';
import '../models/listado_transaccion.dart';
import '../models/producto_inventario.dart';
import '../models/resumen_analisis.dart';
import '../models/resumen_ganancias.dart';
import '../models/totales_mes.dart';
import 'supabase_provider.dart';

class DashboardData {
  const DashboardData({
    required this.totales,
    required this.ganancias,
    required this.resumen,
    required this.flujo,
    required this.recientes,
    required this.inventario,
  });

  final TotalesMes totales;
  final ResumenGanancias ganancias;
  final ResumenAnalisis resumen;
  final List<FlujoDia> flujo;
  final List<ListadoTransaccion> recientes;
  final List<ProductoInventario> inventario;

  bool get vacio =>
      totales.ingresos == 0 &&
      totales.egresos == 0 &&
      flujo.isEmpty &&
      recientes.isEmpty;
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  final totales = await repo.obtenerTotalesMes();
  final ganancias = await repo.obtenerResumenGanancias();
  final resumen = await repo.obtenerResumenAnalisis();
  final flujo = await repo.flujoCaja();
  final recientes = await repo.listadoTransacciones(limite: 6);
  final inventario = await repo.inventario();
  return DashboardData(
    totales: totales,
    ganancias: ganancias,
    resumen: resumen,
    flujo: flujo,
    recientes: recientes,
    inventario: inventario,
  );
});
