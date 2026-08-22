import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/llm_response.dart';
import '../models/producto_inventario.dart';
import '../models/resumen_analisis.dart';
import '../models/tabla_datos.dart';
import '../models/totales_mes.dart';
import '../models/ultima_transaccion.dart';
import '../services/llm_service.dart';
import '../services/supabase_repository.dart';
import 'supabase_provider.dart';

class PendingTransaction {
  const PendingTransaction({
    required this.messageId,
    required this.mensajeParaUsuario,
    required this.datos,
    required this.origen,
    required this.descripcionOriginal,
    this.conversacionId,
  });

  final String messageId;
  final String mensajeParaUsuario;
  final DatosTransaccion datos;
  final String origen;
  final String descripcionOriginal;
  final String? conversacionId;

  PendingTransaction copyWith({
    String? messageId,
    String? mensajeParaUsuario,
    DatosTransaccion? datos,
    String? origen,
    String? descripcionOriginal,
    String? conversacionId,
  }) {
    return PendingTransaction(
      messageId: messageId ?? this.messageId,
      mensajeParaUsuario: mensajeParaUsuario ?? this.mensajeParaUsuario,
      datos: datos ?? this.datos,
      origen: origen ?? this.origen,
      descripcionOriginal: descripcionOriginal ?? this.descripcionOriginal,
      conversacionId: conversacionId ?? this.conversacionId,
    );
  }
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.inputText = '',
    this.inputOrigen = 'texto',
    this.isSending = false,
    this.isSaving = false,
    this.pendingTransaction,
  });

  final List<ChatMessage> messages;
  final String inputText;

  /// 'voz' | 'texto'. Cómo se originó el texto actual del campo editable.
  final String inputOrigen;

  final bool isSending;
  final bool isSaving;
  final PendingTransaction? pendingTransaction;

  bool get canSend => inputText.trim().isNotEmpty;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? inputText,
    String? inputOrigen,
    bool? isSending,
    bool? isSaving,
    PendingTransaction? pendingTransaction,
    bool clearPendingTransaction = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      inputText: inputText ?? this.inputText,
      inputOrigen: inputOrigen ?? this.inputOrigen,
      isSending: isSending ?? this.isSending,
      isSaving: isSaving ?? this.isSaving,
      pendingTransaction: clearPendingTransaction
          ? null
          : pendingTransaction ?? this.pendingTransaction,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._llm, this._repo) : super(const ChatState());

  static const _uuid = Uuid();
  final LlmService _llm;
  final FinanzasRepository _repo;

  void setInputText(String text) {
    state = state.copyWith(inputText: text, inputOrigen: 'texto');
  }

  void setInputFromSpeech(String text) {
    state = state.copyWith(inputText: text, inputOrigen: 'voz');
  }

  void addUserMessage(String text) {
    final message = ChatMessage(
      id: _uuid.v4(),
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      inputText: '',
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final origen = state.inputOrigen;
    addUserMessage(trimmed);
    final historial = _contextoPrevio();
    state = state.copyWith(isSending: true);

    try {
      final response = await _llm.classify(
        text: trimmed,
        historial: historial,
      );

      final intencion = _intencionDe(response.tipoRespuesta);
      String? conversacionId;
      try {
        conversacionId = await _repo.insertarConversacion(
          mensajeUsuario: trimmed,
          intencion: intencion,
          respuestaSistema: response.mensajeParaUsuario,
        );
      } on Exception {
        conversacionId = null;
      }

      if (response.tipoRespuesta == TipoRespuesta.transaccion &&
          response.datosTransaccion != null) {
        state = state.copyWith(
          isSending: false,
          isSaving: false,
          pendingTransaction: PendingTransaction(
            messageId: _uuid.v4(),
            mensajeParaUsuario: response.mensajeParaUsuario,
            datos: response.datosTransaccion!,
            origen: origen,
            descripcionOriginal: trimmed,
            conversacionId: conversacionId,
          ),
        );
        return;
      }

      if (response.tipoRespuesta == TipoRespuesta.consultaReporte) {
        await _manejarConsulta(
          response.datosConsulta,
          response.mensajeParaUsuario,
        );
        return;
      }

      _addAssistantMessage(
        response.mensajeParaUsuario.isEmpty
            ? _fallbackMessage(response.tipoRespuesta)
            : response.mensajeParaUsuario,
      );
    } catch (e) {
      _addAssistantMessage('Lo siento, hubo un error: $e');
    }
  }

  /// Historial de mensajes previos al actual (excluye el mensaje recién
  /// enviado, que se pasa por separado al LLM). Limita a los últimos 20.
  List<ChatMessage> _contextoPrevio() {
    final todos = state.messages;
    if (todos.isEmpty) return const [];

    final previos = todos
        .take(todos.length - 1)
        .where((m) => m.text.trim().isNotEmpty)
        .toList();

    if (previos.length <= 20) return previos;
    return previos.sublist(previos.length - 20);
  }

  String _intencionDe(TipoRespuesta tipoRespuesta) {
    switch (tipoRespuesta) {
      case TipoRespuesta.transaccion:
        return 'transaccional';
      case TipoRespuesta.conversacion:
        return 'conversacional';
      case TipoRespuesta.consultaReporte:
        return 'consulta_reporte';
    }
  }

  String _fallbackMessage(TipoRespuesta tipoRespuesta) {
    switch (tipoRespuesta) {
      case TipoRespuesta.transaccion:
        return 'Detecté una transacción. ¿Puedes repetirla con el monto?';
      case TipoRespuesta.conversacion:
        return 'Claro, dime en qué te ayudo con tu negocio.';
      case TipoRespuesta.consultaReporte:
        return 'La función de reportes aún no está disponible en este prototipo.';
    }
  }

  void _addAssistantMessage(String text, {String? tipoMovimiento}) {
    final message = ChatMessage(
      id: _uuid.v4(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      tipoMovimiento: tipoMovimiento,
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      isSending: false,
      isSaving: false,
    );
  }

  Future<void> _manejarConsulta(
    DatosConsulta? consulta,
    String mensajeDelLlm,
  ) async {
    switch (consulta?.tipoConsulta) {
      case 'analisis':
        await _manejarAnalisis();
        break;
      case 'ultima_transaccion':
        await _manejarUltimaTransaccion(consulta!);
        break;
      case 'listado':
        await _manejarListado(consulta!, mensajeDelLlm);
        break;
      case 'flujo_caja':
        await _manejarFlujoCaja(mensajeDelLlm);
        break;
      case 'inventario':
        await _manejarInventario(mensajeDelLlm);
        break;
      case 'viabilidad':
        await _manejarViabilidad(consulta!);
        break;
      default:
        try {
          final totales = await _repo.obtenerTotalesMes();
          _addReportMessage(
            mensajeDelLlm.isEmpty
                ? 'Estos son tus totales del mes.'
                : mensajeDelLlm,
            totales,
          );
        } on Exception catch (e) {
          _addAssistantMessage('No se pudieron calcular los totales: $e');
        }
    }
  }

  Future<void> _manejarAnalisis() async {
    try {
      final resumen = await _repo.obtenerResumenAnalisis();
      final analisis = await _llm.analizar(resumen: _formatearResumen(resumen));
      _addAssistantMessage(analisis);
    } on Exception catch (e) {
      _addAssistantMessage('No se pudo hacer el análisis: $e');
    }
  }

  Future<void> _manejarUltimaTransaccion(DatosConsulta consulta) async {
    try {
      final tipo = consulta.tipo == 'ingreso' || consulta.tipo == 'egreso'
          ? consulta.tipo
          : null;
      final ultima = await _repo.ultimaTransaccion(tipo: tipo);

      if (ultima == null) {
        _addAssistantMessage(
          'Aún no hay ${tipo == 'ingreso' ? 'ventas' : tipo == 'egreso' ? 'egresos' : 'transacciones'} registradas.',
        );
        return;
      }

      _addAssistantMessage(_formatearUltimaTransaccion(ultima),
          tipoMovimiento: ultima.tipo);
    } on Exception catch (e) {
      _addAssistantMessage('No se pudo consultar la última transacción: $e');
    }
  }

  Future<void> _manejarListado(DatosConsulta consulta, String mensaje) async {
    try {
      final tipo = consulta.tipo == 'ingreso' || consulta.tipo == 'egreso'
          ? consulta.tipo
          : null;
      final lista = await _repo.listadoTransacciones(tipo: tipo);

      if (lista.isEmpty) {
        _addAssistantMessage(
          'Aún no hay ${tipo == 'ingreso' ? 'ingresos' : tipo == 'egreso' ? 'egresos' : 'movimientos'} registrados.',
        );
        return;
      }

      final titulo = tipo == 'ingreso'
          ? 'Mis ingresos'
          : tipo == 'egreso'
              ? 'Mis egresos'
              : 'Mis movimientos';
      final tabla = TablaDatos(
        titulo: titulo,
        headers: const ['Fecha', 'Categoría', 'Monto'],
        columnaColor: 2,
        tipos: lista.map((t) => t.tipo).toList(),
        rows: lista
            .map((t) => [
                  DateFormat('dd/MM').format(t.fecha),
                  t.categoria,
                  'Q${t.monto.toStringAsFixed(2)}',
                ])
            .toList(),
      );
      _addTablaMessage(
        mensaje.isEmpty ? 'Aquí tienes el detalle.' : mensaje,
        tabla,
      );
    } on Exception catch (e) {
      _addAssistantMessage('No se pudo obtener el listado: $e');
    }
  }

  Future<void> _manejarFlujoCaja(String mensaje) async {
    try {
      final dias = await _repo.flujoCaja();

      if (dias.isEmpty) {
        _addAssistantMessage('Aún no hay movimientos en el mes.');
        return;
      }

      final tabla = TablaDatos(
        titulo: 'Flujo de caja del mes',
        headers: const ['Fecha', 'Ingresos', 'Egresos', 'Balance'],
        columnaColor: 3,
        tipos: dias
            .map((d) => d.balance >= 0 ? 'ingreso' : 'egreso')
            .toList(),
        rows: dias
            .map((d) => [
                  DateFormat('dd/MM').format(d.fecha),
                  'Q${d.ingresos.toStringAsFixed(2)}',
                  'Q${d.egresos.toStringAsFixed(2)}',
                  'Q${d.balance.toStringAsFixed(2)}',
                ])
            .toList(),
      );
      _addTablaMessage(
        mensaje.isEmpty ? 'Este es tu flujo de caja del mes.' : mensaje,
        tabla,
      );
    } on Exception catch (e) {
      _addAssistantMessage('No se pudo obtener el flujo de caja: $e');
    }
  }

  Future<void> _manejarInventario(String mensaje) async {
    try {
      final productos = await _repo.inventario();

      if (productos.isEmpty) {
        _addAssistantMessage('Aún no hay productos registrados.');
        return;
      }

      final valorTotal = productos.fold<double>(
          0, (acc, p) => acc + p.valorTotal);
      final tabla = TablaDatos(
        titulo: 'Inventario ($productos.length productos)',
        headers: const ['Producto', 'Compra', 'Venta', 'Exist.', 'Valor'],
        rows: productos
            .map((p) => [
                  p.nombre,
                  'Q${p.precioCompra.toStringAsFixed(2)}',
                  'Q${p.precioVenta.toStringAsFixed(2)}',
                  p.existencias.toStringAsFixed(0),
                  'Q${p.valorTotal.toStringAsFixed(2)}',
                ])
            .toList(),
      );
      final texto = mensaje.isEmpty
          ? 'Inventario actual (valor total Q${valorTotal.toStringAsFixed(2)}).'
          : '$mensaje Valor total: Q${valorTotal.toStringAsFixed(2)}.';
      _addTablaMessage(texto, tabla);
    } on Exception catch (e) {
      _addAssistantMessage('No se pudo obtener el inventario: $e');
    }
  }

  Future<void> _manejarViabilidad(DatosConsulta consulta) async {
    final monto = consulta.monto ?? 0;
    if (monto <= 0) {
      _addAssistantMessage(
        '¿De cuánto es la compra que quieres evaluar? Dime el monto.',
      );
      return;
    }

    try {
      final resumen = await _repo.obtenerResumenAnalisis();
      final productos = await _repo.inventario();
      final texto = _formatearPlanCompra(monto, resumen, productos);
      final analisis = await _llm.analizar(
        resumen: texto,
        prompt: LlmService.viabilidadPrompt,
      );
      _addAssistantMessage(analisis);
    } on Exception catch (e) {
      _addAssistantMessage('No se pudo evaluar la viabilidad: $e');
    }
  }

  String _formatearPlanCompra(
    double monto,
    ResumenAnalisis resumen,
    List<ProductoInventario> productos,
  ) {
    final valorInventario =
        productos.fold<double>(0, (acc, p) => acc + p.valorTotal);
    final buffer = StringBuffer()
      ..writeln('Plan de compra: Q${monto.toStringAsFixed(2)}')
      ..writeln('Resumen del mes actual (montos en quetzales):')
      ..writeln('Ingresos: Q${resumen.ingresos.toStringAsFixed(2)} '
          '(${resumen.cantidadIngresos} movimientos)')
      ..writeln('Egresos: Q${resumen.egresos.toStringAsFixed(2)} '
          '(${resumen.cantidadEgresos} movimientos)')
      ..writeln('Balance: Q${resumen.balance.toStringAsFixed(2)}')
      ..writeln('Valor total del inventario actual: '
          'Q${valorInventario.toStringAsFixed(2)}');
    return buffer.toString();
  }

  String _formatearUltimaTransaccion(UltimaTransaccion ultima) {
    final esIngreso = ultima.tipo == 'ingreso';
    final palabra = esIngreso ? 'última venta' : 'último egreso';
    final fecha = DateFormat('dd/MM/yyyy').format(ultima.fecha);
    return '$palabra: Q${ultima.monto.toStringAsFixed(2)} '
        'en ${ultima.categoria} (el $fecha).';
  }

  String _formatearResumen(ResumenAnalisis resumen) {
    final buffer = StringBuffer()
      ..writeln('Resumen del mes actual (montos en quetzales):')
      ..writeln('Ingresos: Q${resumen.ingresos.toStringAsFixed(2)} '
          '(${resumen.cantidadIngresos} movimientos)')
      ..writeln('Egresos: Q${resumen.egresos.toStringAsFixed(2)} '
          '(${resumen.cantidadEgresos} movimientos)')
      ..writeln('Balance: Q${resumen.balance.toStringAsFixed(2)}');

    if (resumen.porCategoria.isNotEmpty) {
      buffer.writeln('Desglose por categoría:');
      for (final c in resumen.porCategoria) {
        buffer.writeln('- ${c.nombre} (${c.tipo}): '
            'Q${c.total.toStringAsFixed(2)} (${c.cantidad})');
      }
    }
    return buffer.toString();
  }

  void _addReportMessage(String text, TotalesMes totales) {
    final message = ChatMessage(
      id: _uuid.v4(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      reporte: totales,
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      isSending: false,
      isSaving: false,
    );
  }

  void _addTablaMessage(String text, TablaDatos tabla) {
    final message = ChatMessage(
      id: _uuid.v4(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      tabla: tabla,
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      isSending: false,
      isSaving: false,
    );
  }

  Future<void> acceptPendingTransaction() async {
    final pending = state.pendingTransaction;
    if (pending == null) return;

    state = state.copyWith(clearPendingTransaction: true, isSaving: true);

    try {
      await _persistir(pending).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw PersistException(
          'Tiempo de espera agotado al guardar.',
        ),
      );

      final d = pending.datos;
      final monto = 'Q${d.monto.toStringAsFixed(2)}';
      final tipo = d.tipo == 'ingreso' ? 'Ingreso' : 'Egreso';
      final categoria = d.categoriaNivel2Sugerida.isNotEmpty
          ? '${d.categoriaNivel1Sugerida} › ${d.categoriaNivel2Sugerida}'
          : d.categoriaNivel1Sugerida;
      _addAssistantMessage(
        '✓ Registrado: $tipo de $monto en $categoria.',
        tipoMovimiento: d.tipo,
      );
    } catch (e) {
      state = state.copyWith(isSaving: false, pendingTransaction: pending);
      _addAssistantMessage('No se pudo guardar la transacción: $e');
    }
  }

  Future<void> _persistir(PendingTransaction pending) async {
    final categoriaId = await _repo.buscarOCrearCategoriaNivel2(
      categoriaNivel1: pending.datos.categoriaNivel1Sugerida,
      categoriaNivel2: pending.datos.categoriaNivel2Sugerida,
      tipo: pending.datos.tipo,
    );

    final transaccionId = await _repo.insertarTransaccion(
      categoriaId: categoriaId,
      monto: pending.datos.monto,
      tipo: pending.datos.tipo,
      descripcionOriginal: pending.descripcionOriginal,
      descripcionNormalizada: pending.mensajeParaUsuario,
      origen: pending.origen,
      confianza: pending.datos.confianza,
    );

    final conversacionId = pending.conversacionId;
    if (conversacionId != null) {
      await _repo.actualizarTransaccionEnConversacion(
        conversacionId: conversacionId,
        transaccionId: transaccionId,
      );
    }
  }

  void updatePendingTransaction({
    required double monto,
    required String tipo,
    required String categoriaNivel1,
    required String categoriaNivel2,
  }) {
    final pending = state.pendingTransaction;
    if (pending == null) return;

    state = state.copyWith(
      pendingTransaction: pending.copyWith(
        datos: DatosTransaccion(
          monto: monto,
          tipo: tipo,
          categoriaNivel1Sugerida: categoriaNivel1,
          categoriaNivel2Sugerida: categoriaNivel2,
          confianza: pending.datos.confianza,
        ),
      ),
    );
  }

  void cancelPendingTransaction() {
    state = state.copyWith(clearPendingTransaction: true);
  }
}

final llmServiceProvider = Provider<LlmService>((ref) {
  return LlmService(
    apiKey: dotenv.env['LLM_API_KEY'] ?? '',
    baseUrl: dotenv.env['LLM_BASE_URL'] ?? 'https://api.deepseek.com',
    model: dotenv.env['LLM_MODEL'] ?? 'deepseek-chat',
  );
});

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(
    ref.watch(llmServiceProvider),
    ref.watch(supabaseRepositoryProvider),
  ),
);
