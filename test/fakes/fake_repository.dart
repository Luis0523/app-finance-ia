import 'package:finanzas_ia/models/totales_mes.dart';
import 'package:finanzas_ia/services/supabase_repository.dart';

class FakeRepository implements FinanzasRepository {

  bool failOnPersist = false;
  Object? errorEnInsertar;
  int categoriaBusquedas = 0;
  int transacciones = 0;
  int conversaciones = 0;
  int conversacionesActualizadas = 0;
  int totalesConsultas = 0;
  String? lastCategoriaId;
  String? lastTransaccionId;
  String? lastConversacionId;
  TotalesMes totalesMes = const TotalesMes(
    ingresos: 500,
    egresos: 300,
    cantidadIngresos: 2,
    cantidadEgresos: 1,
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
  }) async {
    if (errorEnInsertar != null) throw errorEnInsertar!;
    if (failOnPersist) throw PersistException('error simulado de persistencia');
    transacciones++;
    lastTransaccionId = 'transaccion-$transacciones';
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
}
