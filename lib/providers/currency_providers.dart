import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_rate.dart';
import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import 'subscription_providers.dart';

/// Currency service singleton provider
final currencyServiceProvider = Provider<CurrencyService>((ref) {
  return CurrencyService();
});

/// User's preferred display currency (persisted to preferences)
final displayCurrencyProvider = StateNotifierProvider<DisplayCurrencyNotifier, String>((ref) {
  return DisplayCurrencyNotifier();
});

/// Notifier for display currency that persists changes to preferences
class DisplayCurrencyNotifier extends StateNotifier<String> {
  DisplayCurrencyNotifier() : super(_loadInitialCurrency());

  static String _loadInitialCurrency() {
    try {
      final prefs = PreferencesService().getPreferences();
      final saved = prefs.displayCurrency;
      // If display currency doesn't match any subscription currency, auto-detect
      final detected = _detectCurrencyFromSubscriptions();
      if (detected != null && detected != saved) {
        final subs = DatabaseService().getActiveSubscriptions();
        final subCurrencies = subs.map((s) => s.currency).toSet();
        if (!subCurrencies.contains(saved)) {
          debugPrint('Auto-detected display currency: $detected');
          return detected;
        }
      }
      return saved;
    } catch (e) {
      return 'USD';
    }
  }

  /// Detect the most common currency from user's subscriptions
  static String? _detectCurrencyFromSubscriptions() {
    try {
      final subs = DatabaseService().getActiveSubscriptions();
      if (subs.isEmpty) return null;
      // Count currency occurrences
      final counts = <String, int>{};
      for (final sub in subs) {
        counts[sub.currency] = (counts[sub.currency] ?? 0) + 1;
      }
      // Return the most common one
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.first.key;
    } catch (e) {
      return null;
    }
  }

  void setCurrency(String currency) {
    state = currency;
    _persistCurrency(currency);
  }

  Future<void> _persistCurrency(String currency) async {
    try {
      final prefs = PreferencesService().getPreferences();
      await PreferencesService().updatePreferences(
        prefs.copyWith(displayCurrency: currency),
      );
    } catch (e) {
      // Log but don't throw - state is already updated
    }
  }
}

/// Exchange rates provider (async)
final exchangeRatesProvider = FutureProvider<ExchangeRateCache?>((ref) async {
  final service = ref.read(currencyServiceProvider);
  return await service.getRates();
});

/// Refresh exchange rates
final refreshRatesProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final service = ref.read(currencyServiceProvider);
    await service.getRates(forceRefresh: true);
    ref.invalidate(exchangeRatesProvider);
  };
});

/// Last rates update time provider
final lastRatesUpdateProvider = Provider<DateTime?>((ref) {
  final rates = ref.watch(exchangeRatesProvider);
  return rates.whenData((r) => r?.lastUpdated).value;
});

/// Check if rates are stale (>24h old)
final ratesStaleProvider = Provider<bool>((ref) {
  final rates = ref.watch(exchangeRatesProvider);
  return rates.whenData((r) => r?.isStale ?? true).value ?? true;
});

/// Convert total monthly spend to display currency
final convertedTotalSpendProvider = Provider<double>((ref) {
  final subscriptions = ref.watch(subscriptionProvider).value ?? [];
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final rates = ref.watch(exchangeRatesProvider).value;
  final service = ref.read(currencyServiceProvider);

  double total = 0;
  for (final sub in subscriptions) {
    if (!sub.isArchived && sub.deletedAt == null) {
      total += service.convert(
        amount: sub.monthlyEquivalent,
        from: sub.currency,
        to: displayCurrency,
        rates: rates,
      );
    }
  }

  return total;
});

/// Format amount in display currency
final formatCurrencyProvider = Provider.family<String, double>((ref, amount) {
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final service = ref.read(currencyServiceProvider);
  return service.formatAmount(amount, displayCurrency);
});

/// Available currencies provider
final availableCurrenciesProvider = Provider<List<CurrencyInfo>>((ref) {
  return CurrencyInfo.all;
});

/// Get currency info by code
final currencyInfoProvider = Provider.family<CurrencyInfo?, String>((ref, code) {
  return CurrencyInfo.getByCode(code);
});
