import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/exchange_rate.dart';
import '../utils/constants.dart';

/// Service for currency conversion and exchange rate management
class CurrencyService {
  CurrencyService._();
  static final CurrencyService _instance = CurrencyService._();
  factory CurrencyService() => _instance;

  Box<ExchangeRateCache>? _ratesBox;
  static const String _cacheKey = 'exchange_rates';

  // Frankfurter API - free, no key required
  static const String _apiBaseUrl = 'https://api.frankfurter.app';

  /// Initialize the service
  Future<void> initialize() async {
    _ratesBox = await Hive.openBox<ExchangeRateCache>(
      AppConstants.exchangeRatesBox,
    );
  }

  /// Get cached exchange rates
  ExchangeRateCache? getCachedRates() {
    return _ratesBox?.get(_cacheKey);
  }

  /// Check if cache is valid
  bool isCacheValid() {
    final cache = getCachedRates();
    return cache != null && cache.isValid;
  }

  /// Fetch latest exchange rates from API
  Future<ExchangeRateCache?> fetchLatestRates({String baseCurrency = 'USD'}) async {
    try {
      final url = Uri.parse('$_apiBaseUrl/latest?from=$baseCurrency');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = (data['rates'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, (value as num).toDouble()));

        final cache = ExchangeRateCache(
          baseCurrency: baseCurrency,
          rates: rates,
          lastUpdated: DateTime.now(),
        );

        await _ratesBox?.put(_cacheKey, cache);
        debugPrint('Currency rates fetched successfully: ${rates.length} currencies');
        return cache;
      } else {
        debugPrint('Failed to fetch rates: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching exchange rates: $e');
      return null;
    }
  }

  /// Get exchange rates (from cache or fetch if needed)
  Future<ExchangeRateCache?> getRates({bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid()) {
      return getCachedRates();
    }
    return await fetchLatestRates();
  }

  /// Convert amount from one currency to another
  double convert({
    required double amount,
    required String from,
    required String to,
    ExchangeRateCache? rates,
  }) {
    if (from == to) return amount;

    final cache = rates ?? getCachedRates();
    if (cache == null) {
      debugPrint('No exchange rates available, returning original amount');
      return amount;
    }

    // If the base currency matches 'from', we can directly use the rate
    if (cache.baseCurrency == from) {
      final rate = cache.getRate(to);
      if (rate != null) {
        return amount * rate;
      }
    }

    // Otherwise, we need to convert via the base currency
    final fromRate = cache.getRate(from);
    final toRate = cache.getRate(to);

    if (fromRate != null && toRate != null) {
      // Convert to base currency, then to target currency
      final inBase = amount / fromRate;
      return inBase * toRate;
    }

    // If we can't convert, return original amount
    debugPrint('Unable to convert $from to $to');
    return amount;
  }

  /// Like [convert], but returns `null` when the cache is missing or the
  /// rate pair is unresolvable — instead of silently passing the input
  /// through (which stamps a wrong value with the display-currency symbol).
  /// Callers that need to surface "rates not available" should use this.
  double? convertOrNull({
    required double amount,
    required String from,
    required String to,
    ExchangeRateCache? rates,
  }) {
    if (from == to) return amount;

    final cache = rates ?? getCachedRates();
    if (cache == null) return null;

    if (cache.baseCurrency == from) {
      final rate = cache.getRate(to);
      return rate == null ? null : amount * rate;
    }

    final fromRate = cache.getRate(from);
    final toRate = cache.getRate(to);
    if (fromRate == null || toRate == null) return null;

    return amount / fromRate * toRate;
  }

  /// Format amount with currency symbol
  String formatAmount(double amount, String currencyCode) {
    final info = CurrencyInfo.getByCode(currencyCode);
    final symbol = info?.symbol ?? currencyCode;

    // Format with appropriate decimal places
    String formatted;
    if (currencyCode == 'JPY' || currencyCode == 'KRW') {
      // No decimal places for these currencies
      formatted = amount.round().toString();
    } else {
      formatted = amount.toStringAsFixed(2);
    }

    // Add thousand separators
    final parts = formatted.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    if (parts.length > 1) {
      formatted = '$intPart.${parts[1]}';
    } else {
      formatted = intPart;
    }

    return '$symbol$formatted';
  }

  /// Get the last update time
  DateTime? getLastUpdateTime() {
    return getCachedRates()?.lastUpdated;
  }

  /// Clear cached rates
  Future<void> clearCache() async {
    await _ratesBox?.delete(_cacheKey);
  }

  /// Watch for rate changes
  Stream<BoxEvent>? watchRates() {
    return _ratesBox?.watch(key: _cacheKey);
  }

  /// Close the service
  Future<void> close() async {
    await _ratesBox?.close();
  }
}
