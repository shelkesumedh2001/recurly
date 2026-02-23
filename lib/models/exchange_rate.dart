import 'package:hive/hive.dart';

part 'exchange_rate.g.dart';

/// Cached exchange rates data
@HiveType(typeId: 8)
class ExchangeRateCache extends HiveObject {
  ExchangeRateCache({
    required this.baseCurrency,
    required this.rates,
    required this.lastUpdated,
    DateTime? expiresAt,
  }) : expiresAt = expiresAt ?? lastUpdated.add(const Duration(hours: 24));

  /// Base currency code (e.g., 'USD')
  @HiveField(0)
  String baseCurrency;

  /// Exchange rates: currency code -> rate
  /// Rate represents how much of that currency equals 1 unit of base currency
  @HiveField(1)
  Map<String, double> rates;

  /// When the rates were last fetched
  @HiveField(2)
  DateTime lastUpdated;

  /// When the cache expires (default 24 hours from last update)
  @HiveField(3)
  DateTime expiresAt;

  /// Check if cache is still valid
  bool get isValid => DateTime.now().isBefore(expiresAt);

  /// Check if cache is stale (>24 hours old)
  bool get isStale => DateTime.now().difference(lastUpdated).inHours > 24;

  /// Get rate for a currency
  double? getRate(String currency) {
    if (currency == baseCurrency) return 1.0;
    return rates[currency];
  }

  /// Copy with updated fields
  ExchangeRateCache copyWith({
    String? baseCurrency,
    Map<String, double>? rates,
    DateTime? lastUpdated,
    DateTime? expiresAt,
  }) {
    return ExchangeRateCache(
      baseCurrency: baseCurrency ?? this.baseCurrency,
      rates: rates ?? Map.from(this.rates),
      lastUpdated: lastUpdated ?? this.lastUpdated,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  String toString() {
    return 'ExchangeRateCache(base: $baseCurrency, rates: ${rates.length}, valid: $isValid)';
  }
}

/// Supported currencies with display info
class CurrencyInfo {
  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    this.flag,
  });

  final String code;
  final String name;
  final String symbol;
  final String? flag;

  /// All supported currencies
  static const List<CurrencyInfo> all = [
    CurrencyInfo(code: 'USD', name: 'US Dollar', symbol: '\$', flag: '🇺🇸'),
    CurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺'),
    CurrencyInfo(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧'),
    CurrencyInfo(code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳'),
    CurrencyInfo(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵'),
    CurrencyInfo(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', flag: '🇨🇦'),
    CurrencyInfo(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flag: '🇦🇺'),
    CurrencyInfo(code: 'CHF', name: 'Swiss Franc', symbol: 'Fr', flag: '🇨🇭'),
    CurrencyInfo(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳'),
    CurrencyInfo(code: 'KRW', name: 'South Korean Won', symbol: '₩', flag: '🇰🇷'),
    CurrencyInfo(code: 'MXN', name: 'Mexican Peso', symbol: '\$', flag: '🇲🇽'),
    CurrencyInfo(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', flag: '🇧🇷'),
    CurrencyInfo(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', flag: '🇸🇬'),
    CurrencyInfo(code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK\$', flag: '🇭🇰'),
    CurrencyInfo(code: 'SEK', name: 'Swedish Krona', symbol: 'kr', flag: '🇸🇪'),
    CurrencyInfo(code: 'NOK', name: 'Norwegian Krone', symbol: 'kr', flag: '🇳🇴'),
    CurrencyInfo(code: 'DKK', name: 'Danish Krone', symbol: 'kr', flag: '🇩🇰'),
    CurrencyInfo(code: 'PLN', name: 'Polish Zloty', symbol: 'zł', flag: '🇵🇱'),
    CurrencyInfo(code: 'THB', name: 'Thai Baht', symbol: '฿', flag: '🇹🇭'),
    CurrencyInfo(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', flag: '🇲🇾'),
  ];

  /// Get currency info by code
  static CurrencyInfo? getByCode(String code) {
    try {
      return all.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Get symbol for a currency code
  static String getSymbol(String code) {
    return getByCode(code)?.symbol ?? code;
  }
}
