import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/exchange_rate.dart';
import 'package:recurly/services/currency_service.dart';

ExchangeRateCache _cache({
  String base = 'USD',
  Map<String, double> rates = const {},
}) {
  return ExchangeRateCache(
    baseCurrency: base,
    rates: rates,
    lastUpdated: DateTime(2025, 6, 15),
  );
}

void main() {
  final service = CurrencyService();

  group('convertOrNull', () {
    test('from == to returns the input amount (no cache needed)', () {
      final result = service.convertOrNull(
        amount: 42,
        from: 'USD',
        to: 'USD',
        rates: null,
      );
      expect(result, 42.0);
    });

    test('null cache → null (surfaces the failure)', () {
      final result = service.convertOrNull(
        amount: 100,
        from: 'USD',
        to: 'EUR',
        rates: null,
      );
      expect(result, isNull);
    });

    test('base == from, rate present → converts', () {
      final cache = _cache(base: 'USD', rates: {'EUR': 0.9});
      final result = service.convertOrNull(
        amount: 100,
        from: 'USD',
        to: 'EUR',
        rates: cache,
      );
      expect(result, closeTo(90.0, 1e-9));
    });

    test('base == from, rate missing → null (not silent passthrough)', () {
      final cache = _cache(base: 'USD', rates: {'EUR': 0.9});
      final result = service.convertOrNull(
        amount: 100,
        from: 'USD',
        to: 'XYZ',
        rates: cache,
      );
      expect(result, isNull);
    });

    test('cross-rate via base (from != base, to != base)', () {
      final cache = _cache(base: 'USD', rates: {'EUR': 0.9, 'GBP': 0.8});
      final result = service.convertOrNull(
        amount: 90,
        from: 'EUR',
        to: 'GBP',
        rates: cache,
      );
      expect(result, closeTo(90 / 0.9 * 0.8, 1e-9));
    });

    test('fromRate missing → null', () {
      final cache = _cache(base: 'USD', rates: {'GBP': 0.8});
      final result = service.convertOrNull(
        amount: 100,
        from: 'XYZ',
        to: 'GBP',
        rates: cache,
      );
      expect(result, isNull);
    });

    test('toRate missing → null', () {
      final cache = _cache(base: 'USD', rates: {'EUR': 0.9});
      final result = service.convertOrNull(
        amount: 100,
        from: 'EUR',
        to: 'XYZ',
        rates: cache,
      );
      expect(result, isNull);
    });
  });
}
