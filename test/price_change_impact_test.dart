import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/exchange_rate.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/providers/analytics_providers.dart';
import 'package:recurly/services/currency_service.dart';

Subscription _subWithPriceChange({
  required String id,
  required String currency,
  required double oldPrice,
  required double newPrice,
  BillingCycle cycle = BillingCycle.monthly,
}) {
  return Subscription(
    id: id,
    name: id,
    price: newPrice,
    currency: currency,
    billingCycle: cycle,
    firstBillDate: DateTime(2025, 1, 1),
    category: SubscriptionCategory.other,
    createdAt: DateTime(2025, 1, 1),
    priceHistory: [
      {
        'price': oldPrice,
        'currency': currency,
        'date': DateTime(2025, 1, 1).toIso8601String(),
      },
    ],
  );
}

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

  group('computeTotalPriceChangeImpact', () {
    test('empty list → 0', () {
      final result = computeTotalPriceChangeImpact(
        subs: const [],
        currencyService: service,
        displayCurrency: 'USD',
        rates: null,
      );
      expect(result, 0.0);
    });

    test('single monthly sub, same currency → raw diff', () {
      final sub = _subWithPriceChange(
        id: 'netflix',
        currency: 'USD',
        oldPrice: 10,
        newPrice: 15,
      );
      final result = computeTotalPriceChangeImpact(
        subs: [sub],
        currencyService: service,
        displayCurrency: 'USD',
        rates: null,
      );
      expect(result, closeTo(5.0, 1e-9));
    });

    test('yearly sub → monthly equivalent (÷12)', () {
      final sub = _subWithPriceChange(
        id: 'prime',
        currency: 'USD',
        oldPrice: 100,
        newPrice: 112,
        cycle: BillingCycle.yearly,
      );
      final result = computeTotalPriceChangeImpact(
        subs: [sub],
        currencyService: service,
        displayCurrency: 'USD',
        rates: null,
      );
      expect(result, closeTo(1.0, 1e-9));
    });

    test('USD + EUR subs, displayCurrency USD → converted via rates', () {
      final usdSub = _subWithPriceChange(
        id: 'netflix',
        currency: 'USD',
        oldPrice: 10,
        newPrice: 15,
      );
      final eurSub = _subWithPriceChange(
        id: 'spotify',
        currency: 'EUR',
        oldPrice: 8,
        newPrice: 10,
      );
      final rates = _cache(base: 'USD', rates: {'EUR': 0.9});

      final result = computeTotalPriceChangeImpact(
        subs: [usdSub, eurSub],
        currencyService: service,
        displayCurrency: 'USD',
        rates: rates,
      );

      // USD diff: 5.0
      // EUR diff: 2.0 → to USD at 1/0.9 ≈ 2.2222
      expect(result, closeTo(5.0 + 2.0 / 0.9, 1e-9));
    });

    test('missing rate for a sub → null (not silent wrong value)', () {
      final usdSub = _subWithPriceChange(
        id: 'netflix',
        currency: 'USD',
        oldPrice: 10,
        newPrice: 15,
      );
      final unknownSub = _subWithPriceChange(
        id: 'weird',
        currency: 'XYZ',
        oldPrice: 8,
        newPrice: 10,
      );
      final rates = _cache(base: 'USD', rates: {'EUR': 0.9});

      final result = computeTotalPriceChangeImpact(
        subs: [usdSub, unknownSub],
        currencyService: service,
        displayCurrency: 'USD',
        rates: rates,
      );

      expect(result, isNull);
    });

    test('null cache with cross-currency sub → null', () {
      final eurSub = _subWithPriceChange(
        id: 'spotify',
        currency: 'EUR',
        oldPrice: 8,
        newPrice: 10,
      );
      final result = computeTotalPriceChangeImpact(
        subs: [eurSub],
        currencyService: service,
        displayCurrency: 'USD',
        rates: null,
      );
      expect(result, isNull);
    });

    test('price decrease → negative impact preserved', () {
      final sub = _subWithPriceChange(
        id: 'gym',
        currency: 'USD',
        oldPrice: 20,
        newPrice: 15,
      );
      final result = computeTotalPriceChangeImpact(
        subs: [sub],
        currencyService: service,
        displayCurrency: 'USD',
        rates: null,
      );
      expect(result, closeTo(-5.0, 1e-9));
    });
  });
}
