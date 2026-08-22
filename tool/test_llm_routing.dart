import 'dart:io';

import 'package:finanzas_ia/models/llm_response.dart';
import 'package:finanzas_ia/services/llm_config.dart';

class _Caso {
  const _Caso(this.mensaje, this.esperado, {this.comentario});

  final String mensaje;
  final TipoRespuesta esperado;
  final String? comentario;
}

const _casos = [
  _Caso('vendí Q200 de fruta hoy', TipoRespuesta.transaccion),
  _Caso('compré mercadería por Q150 en el mercado', TipoRespuesta.transaccion),
  _Caso('pagué la renta del local, Q500', TipoRespuesta.transaccion),
  _Caso('recibí Q50 de comisión por venta', TipoRespuesta.transaccion),
  _Caso(
    'le puse Q300 de gasolina al carro del negocio',
    TipoRespuesta.transaccion,
  ),
  _Caso('saqué Q200 para mis gastos personales', TipoRespuesta.transaccion),
  _Caso('me prestaron Q2000 del banco', TipoRespuesta.transaccion),
  _Caso(
    'compré una refrigeradora en Q1500 para la tienda',
    TipoRespuesta.transaccion,
  ),
  _Caso('le pagué Q100 al muchacho por el reparto', TipoRespuesta.transaccion),
  _Caso(
    'pagué la luz del negocio',
    TipoRespuesta.conversacion,
    comentario: 'Sin monto: debe pedir el monto antes de registrar',
  ),
  _Caso('hola', TipoRespuesta.conversacion),
  _Caso('buenos días, que tal', TipoRespuesta.conversacion),
  _Caso('¿cómo estás?', TipoRespuesta.conversacion),
  _Caso('gracias', TipoRespuesta.conversacion),
  _Caso(
    'ayer vendí bastante',
    TipoRespuesta.conversacion,
    comentario: 'Ambiguo, sin dato financiero claro',
  ),
  _Caso('¿cuánto tengo de ingresos este mes?', TipoRespuesta.consultaReporte),
  _Caso('muéstrame mis gastos', TipoRespuesta.consultaReporte),
  _Caso('pásame un reporte de ventas', TipoRespuesta.consultaReporte),
];

Future<void> main() async {
  final env = <String, String>{};
  final lines = await File('.env').readAsLines();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx == -1) continue;
    env[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
  }

  final service = llmServiceFromEnv(env);
  if (service.apiKey.isEmpty || service.apiKey.contains('tu_key')) {
    stderr.writeln('ERROR: API key del LLM no configurada en .env');
    exit(1);
  }

  stdout.writeln('Proveedor: ${service.baseUrl} | Modelo: ${service.model}');
  stdout.writeln('Probando ${_casos.length} mensajes reales...\n');

  var aciertos = 0;
  var fallos = 0;

  for (final caso in _casos) {
    try {
      final respuesta = await service.classify(text: caso.mensaje);
      final ok = respuesta.tipoRespuesta == caso.esperado;
      if (ok) {
        aciertos++;
      } else {
        fallos++;
      }

      final icono = ok ? 'OK ' : 'FAIL';
      stdout.writeln('[$icono] "${caso.mensaje}"');
      stdout.writeln(
        '      esperado: ${_nombre(caso.esperado)} '
        '| obtenido: ${_nombre(respuesta.tipoRespuesta)}',
      );
      if (respuesta.tipoRespuesta == TipoRespuesta.transaccion &&
          respuesta.datosTransaccion != null) {
        final d = respuesta.datosTransaccion!;
        stdout.writeln(
          '      datos: Q${d.monto} ${d.tipo} | '
          '${d.categoriaNivel1Sugerida} › ${d.categoriaNivel2Sugerida} '
          '| confianza ${(d.confianza * 100).toStringAsFixed(0)}%',
        );
      }
      if (caso.comentario != null) {
        stdout.writeln('      nota: ${caso.comentario}');
      }
    } on Exception catch (e) {
      fallos++;
      stdout.writeln('[ERR] "${caso.mensaje}" → $e');
    }
  }

  final total = aciertos + fallos;
  final porcentaje = total == 0 ? 0.0 : (aciertos / total) * 100;
  stdout.writeln('\n======================================');
  stdout.writeln(
    'RESULTADO: $aciertos/$total correctos '
    '(${porcentaje.toStringAsFixed(1)}%)',
  );
  stdout.writeln('======================================');
  exit(aciertos == total ? 0 : 1);
}

String _nombre(TipoRespuesta tipo) {
  switch (tipo) {
    case TipoRespuesta.transaccion:
      return 'transaccion';
    case TipoRespuesta.conversacion:
      return 'conversacion';
    case TipoRespuesta.consultaReporte:
      return 'consulta_reporte';
  }
}
