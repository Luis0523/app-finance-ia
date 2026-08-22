import 'package:finanzas_ia/services/supabase_repository.dart';

class FakeRepository implements FinanzasRepository {

  bool failOnPersist = false;
  int categoriaBusquedas = 0;
  int transacciones = 0;
  int conversaciones = 0;
  int conversacionesActualizadas = 0;
  String? lastCategoriaId;
  String? lastTransaccionId;
  String? lastConversacionId;

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
}
