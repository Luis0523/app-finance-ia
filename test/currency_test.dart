import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_ia/utils/currency.dart';

void main() {
  test('reemplaza "quetzales" con símbolo Q', () {
    expect(
      normalizeCurrencyText('Detecté una venta de 200 quetzales. ¿Confirmas?'),
      'Detecté una venta de Q200. ¿Confirmas?',
    );
  });

  test('reemplaza "quetzal" (singular)', () {
    expect(
      normalizeCurrencyText('Pagaste 150.50 quetzal'),
      'Pagaste Q150.50',
    );
  });

  test('evita duplicar Q si el monto ya lo lleva', () {
    expect(
      normalizeCurrencyText('Venta de Q200 quetzales'),
      'Venta de Q200',
    );
  });

  test('reemplaza "quetzales" sueltos sin monto', () {
    expect(
      normalizeCurrencyText('El total en quetzales es'),
      'El total en Q es',
    );
  });
}
