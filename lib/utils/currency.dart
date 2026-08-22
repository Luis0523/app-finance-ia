final _amountWithCurrency = RegExp(
  r'[Qq]\s?(\d+(?:[.,]\d+)?)\s*(?:quetzales?|quetzal)\b',
);

final _amountThenCurrency = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(?:quetzales?|quetzal)\b',
  caseSensitive: false,
);

final _standaloneCurrency = RegExp(r'\bquetzales?\b', caseSensitive: false);

/// Normaliza la moneda a su símbolo [Q], evitando la palabra "quetzal/quetzales"
/// en los textos que devuelve el LLM.
String normalizeCurrencyText(String text) {
  var result = text.replaceAllMapped(
    _amountWithCurrency,
    (m) => 'Q${m[1]}',
  );
  result = result.replaceAllMapped(
    _amountThenCurrency,
    (m) => 'Q${m[1]}',
  );
  result = result.replaceAll(_standaloneCurrency, 'Q');
  return result;
}
