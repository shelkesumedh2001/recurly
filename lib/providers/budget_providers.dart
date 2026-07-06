import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../models/subscription.dart';
import '../services/budget_service.dart';
import '../utils/money.dart';
import 'currency_providers.dart';
import 'subscription_providers.dart';

/// Budget service singleton provider
final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService();
});

/// Budget settings state notifier
class BudgetNotifier extends StateNotifier<BudgetSettings> {
  BudgetNotifier(this._budgetService) : super(BudgetSettings()) {
    _loadSettings();
  }

  final BudgetService _budgetService;

  void _loadSettings() {
    state = _budgetService.getSettings();
  }

  /// Reload settings from storage
  void reload() {
    _loadSettings();
  }

  /// Update overall monthly budget
  Future<void> setOverallBudget(double? amount) async {
    await _budgetService.setOverallBudget(amount);
    _loadSettings();
  }

  /// Update category budget
  Future<void> setCategoryBudget(String categoryName, double? amount) async {
    await _budgetService.setCategoryBudget(categoryName, amount);
    _loadSettings();
  }

  /// Toggle budget alerts
  Future<void> toggleAlerts(bool enabled) async {
    await _budgetService.toggleAlerts(enabled);
    _loadSettings();
  }

  /// Set warning threshold
  Future<void> setWarningThreshold(double threshold) async {
    await _budgetService.setWarningThreshold(threshold);
    _loadSettings();
  }

  /// Clear all budgets
  Future<void> clearAllBudgets() async {
    await _budgetService.clearAllBudgets();
    _loadSettings();
  }
}

/// Main budget settings provider
final budgetSettingsProvider = StateNotifierProvider<BudgetNotifier, BudgetSettings>((ref) {
  final budgetService = ref.watch(budgetServiceProvider);
  return BudgetNotifier(budgetService);
});

/// Budget usage percentage provider (0.0 to 1.0+)
final budgetUsageProvider = Provider<double?>((ref) {
  final settings = ref.watch(budgetSettingsProvider);
  final totalSpend = ref.watch(convertedTotalSpendProvider);

  if (!settings.hasBudget) return null;

  final budgetService = ref.read(budgetServiceProvider);
  return budgetService.calculateUsage(totalSpend, settings.overallMonthlyBudget);
});

/// Budget status provider
final budgetStatusProvider = Provider<BudgetStatus>((ref) {
  final settings = ref.watch(budgetSettingsProvider);
  final totalSpend = ref.watch(convertedTotalSpendProvider);
  final budgetService = ref.read(budgetServiceProvider);

  return budgetService.getStatus(totalSpend, settings);
});

/// Remaining budget provider
final remainingBudgetProvider = Provider<double?>((ref) {
  final settings = ref.watch(budgetSettingsProvider);
  final totalSpend = ref.watch(convertedTotalSpendProvider);
  final budgetService = ref.read(budgetServiceProvider);

  return budgetService.calculateRemaining(totalSpend, settings.overallMonthlyBudget);
});

/// Category budget status provider (family)
final categoryBudgetStatusProvider = Provider.family<BudgetStatus, String>((ref, categoryName) {
  final settings = ref.watch(budgetSettingsProvider);
  final categorySpend = ref.watch(categorySpendByNameProvider)[categoryName] ?? 0.0;
  final budgetService = ref.read(budgetServiceProvider);

  return budgetService.getCategoryStatus(categoryName, categorySpend, settings);
});

/// Category spend keyed by category **display name** (converted to display
/// currency). Distinct from analytics' `categorySpendProvider`, which is keyed
/// by the `SubscriptionCategory` enum.
final categorySpendByNameProvider = Provider<Map<String, double>>((ref) {
  final subscriptions = ref.watch(subscriptionProvider).value ?? [];
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final rates = ref.watch(exchangeRatesProvider).value;
  final currencyService = ref.watch(currencyServiceProvider);

  final Map<String, double> categorySpend = {};
  for (final sub in subscriptions) {
    if (!sub.isArchived && sub.deletedAt == null) {
      final categoryName = sub.category.displayName;
      final converted = currencyService.convert(
        amount: sub.monthlyEquivalent,
        from: sub.currency,
        to: displayCurrency,
        rates: rates,
      );
      categorySpend[categoryName] = (categorySpend[categoryName] ?? 0) + converted;
    }
  }

  return categorySpend.map((k, v) => MapEntry(k, roundMoney(v)));
});

/// Should show budget alert provider
final shouldShowBudgetAlertProvider = Provider<bool>((ref) {
  final settings = ref.watch(budgetSettingsProvider);
  final status = ref.watch(budgetStatusProvider);
  final budgetService = ref.read(budgetServiceProvider);

  return budgetService.shouldShowAlert(settings, status);
});

/// Calendar cash-flow view of the current month against the budget.
///
/// Distinct from the gauge's monthly-equivalent numbers: this sums the
/// charges that actually land on the statement this month, so an annual
/// bill counts in full in its renewal month instead of as 1/12th.
class BudgetForecast {
  const BudgetForecast({
    required this.billedSoFar,
    required this.upcoming,
    required this.upcomingCount,
  });

  /// Pure core: split this calendar month's real charges into already-billed
  /// (1st → [today]) and still-to-come ([today]+1 → month end). [convertedCharge]
  /// returns one renewal's cost in display currency for a given sub, so this
  /// stays currency-agnostic and unit-testable. Archived/soft-deleted subs and
  /// non-positive charges (free trials with no post-trial price) are skipped.
  factory BudgetForecast.forMonth({
    required List<Subscription> subscriptions,
    required DateTime today,
    required double Function(Subscription sub) convertedCharge,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final monthStart = DateTime(day.year, day.month, 1);
    final monthEnd = DateTime(day.year, day.month + 1, 0);

    double billed = 0;
    double upcoming = 0;
    var upcomingCount = 0;

    for (final sub in subscriptions) {
      if (sub.isArchived || sub.deletedAt != null) continue;
      final charge = convertedCharge(sub);
      if (charge <= 0) continue;

      for (final date in sub.renewalsInRange(monthStart, monthEnd)) {
        if (date.isAfter(day)) {
          upcoming += charge;
          upcomingCount++;
        } else {
          billed += charge;
        }
      }
    }

    return BudgetForecast(
      billedSoFar: roundMoney(billed),
      upcoming: roundMoney(upcoming),
      upcomingCount: upcomingCount,
    );
  }

  /// Charges from the 1st through today (inclusive), display currency.
  final double billedSoFar;

  /// Charges after today through month end, display currency.
  final double upcoming;

  /// Number of renewals still to come this month.
  final int upcomingCount;

  /// Where the month ends up if nothing changes.
  double get projected => roundMoney(billedSoFar + upcoming);
}

final budgetForecastProvider = Provider<BudgetForecast?>((ref) {
  final settings = ref.watch(budgetSettingsProvider);
  if (!settings.hasBudget) return null;

  final subscriptions = ref.watch(subscriptionProvider).value ?? [];
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final rates = ref.watch(exchangeRatesProvider).value;
  final service = ref.read(currencyServiceProvider);

  return BudgetForecast.forMonth(
    subscriptions: subscriptions,
    today: clock.now(),
    convertedCharge: (sub) => service.convert(
      amount: sub.chargePerRenewal,
      from: sub.currency,
      to: displayCurrency,
      rates: rates,
    ),
  );
});
