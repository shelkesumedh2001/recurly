import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
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
  final totalSpend = ref.watch(totalMonthlySpendProvider);

  if (!settings.hasBudget) return null;

  final budgetService = ref.read(budgetServiceProvider);
  return budgetService.calculateUsage(totalSpend, settings.overallMonthlyBudget);
});

/// Budget status provider
final budgetStatusProvider = Provider<BudgetStatus>((ref) {
  final settings = ref.watch(budgetSettingsProvider);
  final totalSpend = ref.watch(totalMonthlySpendProvider);
  final budgetService = ref.read(budgetServiceProvider);

  return budgetService.getStatus(totalSpend, settings);
});

/// Remaining budget provider
final remainingBudgetProvider = Provider<double?>((ref) {
  final settings = ref.watch(budgetSettingsProvider);
  final totalSpend = ref.watch(totalMonthlySpendProvider);
  final budgetService = ref.read(budgetServiceProvider);

  return budgetService.calculateRemaining(totalSpend, settings.overallMonthlyBudget);
});

/// Category budget status provider (family)
final categoryBudgetStatusProvider = Provider.family<BudgetStatus, String>((ref, categoryName) {
  final settings = ref.watch(budgetSettingsProvider);
  final categorySpend = ref.watch(categorySpendProvider)[categoryName] ?? 0.0;
  final budgetService = ref.read(budgetServiceProvider);

  return budgetService.getCategoryStatus(categoryName, categorySpend, settings);
});

/// Category spend provider (from analytics_providers)
final categorySpendProvider = Provider<Map<String, double>>((ref) {
  final subscriptions = ref.watch(subscriptionProvider).value ?? [];

  final Map<String, double> categorySpend = {};
  for (final sub in subscriptions) {
    if (!sub.isArchived && sub.deletedAt == null) {
      final categoryName = sub.category.displayName;
      categorySpend[categoryName] = (categorySpend[categoryName] ?? 0) + sub.monthlyEquivalent;
    }
  }

  return categorySpend;
});

/// Should show budget alert provider
final shouldShowBudgetAlertProvider = Provider<bool>((ref) {
  final settings = ref.watch(budgetSettingsProvider);
  final status = ref.watch(budgetStatusProvider);
  final budgetService = ref.read(budgetServiceProvider);

  return budgetService.shouldShowAlert(settings, status);
});
