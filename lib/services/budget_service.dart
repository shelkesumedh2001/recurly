import 'package:hive_flutter/hive_flutter.dart';
import '../models/budget.dart';
import '../utils/constants.dart';

/// Service for managing budget settings and calculations
class BudgetService {
  BudgetService._();
  static final BudgetService _instance = BudgetService._();
  factory BudgetService() => _instance;

  Box<BudgetSettings>? _budgetBox;
  static const String _settingsKey = 'budget_settings';

  /// Initialize the budget service
  Future<void> initialize() async {
    _budgetBox = await Hive.openBox<BudgetSettings>(
      AppConstants.budgetBox,
    );
  }

  /// Get current budget settings
  BudgetSettings getSettings() {
    return _budgetBox?.get(_settingsKey) ?? BudgetSettings();
  }

  /// Save budget settings
  Future<void> saveSettings(BudgetSettings settings) async {
    await _budgetBox?.put(_settingsKey, settings);
  }

  /// Watch for settings changes
  Stream<BoxEvent>? watchSettings() {
    return _budgetBox?.watch(key: _settingsKey);
  }

  /// Calculate budget usage percentage
  /// Returns a value between 0.0 and potentially > 1.0 if over budget
  double calculateUsage(double totalSpend, double? budget) {
    if (budget == null || budget <= 0) return 0;
    return totalSpend / budget;
  }

  /// Get budget status based on usage
  BudgetStatus getStatus(double totalSpend, BudgetSettings settings) {
    if (!settings.hasBudget) {
      return BudgetStatus.noBudget;
    }

    final usage = calculateUsage(totalSpend, settings.overallMonthlyBudget);

    if (usage >= 1.0) {
      return BudgetStatus.exceeded;
    } else if (usage >= settings.warningThreshold) {
      return BudgetStatus.warning;
    } else {
      return BudgetStatus.safe;
    }
  }

  /// Get category budget status
  BudgetStatus getCategoryStatus(
    String categoryName,
    double categorySpend,
    BudgetSettings settings,
  ) {
    final categoryBudget = settings.getCategoryBudget(categoryName);
    if (categoryBudget == null || categoryBudget <= 0) {
      return BudgetStatus.noBudget;
    }

    final usage = calculateUsage(categorySpend, categoryBudget);

    if (usage >= 1.0) {
      return BudgetStatus.exceeded;
    } else if (usage >= settings.warningThreshold) {
      return BudgetStatus.warning;
    } else {
      return BudgetStatus.safe;
    }
  }

  /// Calculate remaining budget
  double? calculateRemaining(double totalSpend, double? budget) {
    if (budget == null || budget <= 0) return null;
    return budget - totalSpend;
  }

  /// Check if budget alert should be shown
  bool shouldShowAlert(BudgetSettings settings, BudgetStatus status) {
    if (!settings.budgetAlertsEnabled) return false;
    if (status == BudgetStatus.safe || status == BudgetStatus.noBudget) {
      return false;
    }

    // Avoid showing alerts more than once per day
    if (settings.lastBudgetAlertShown != null) {
      final hoursSinceLastAlert = DateTime.now()
          .difference(settings.lastBudgetAlertShown!)
          .inHours;
      if (hoursSinceLastAlert < 24) return false;
    }

    return true;
  }

  /// Mark alert as shown
  Future<void> markAlertShown() async {
    final settings = getSettings();
    await saveSettings(
      settings.copyWith(lastBudgetAlertShown: DateTime.now()),
    );
  }

  /// Set overall monthly budget
  Future<void> setOverallBudget(double? amount) async {
    final settings = getSettings();
    await saveSettings(
      settings.copyWith(
        overallMonthlyBudget: amount,
        clearOverallBudget: amount == null,
      ),
    );
  }

  /// Set category budget
  Future<void> setCategoryBudget(String categoryName, double? amount) async {
    final settings = getSettings();
    final newCategoryBudgets = Map<String, double>.from(settings.categoryBudgets);

    if (amount == null || amount <= 0) {
      newCategoryBudgets.remove(categoryName);
    } else {
      newCategoryBudgets[categoryName] = amount;
    }

    await saveSettings(
      settings.copyWith(categoryBudgets: newCategoryBudgets),
    );
  }

  /// Toggle budget alerts
  Future<void> toggleAlerts(bool enabled) async {
    final settings = getSettings();
    await saveSettings(
      settings.copyWith(budgetAlertsEnabled: enabled),
    );
  }

  /// Set warning threshold
  Future<void> setWarningThreshold(double threshold) async {
    final settings = getSettings();
    await saveSettings(
      settings.copyWith(
        warningThreshold: threshold.clamp(0.5, 0.95),
      ),
    );
  }

  /// Clear all budget settings
  Future<void> clearAllBudgets() async {
    await saveSettings(BudgetSettings());
  }

  /// Close the service
  Future<void> close() async {
    await _budgetBox?.close();
  }
}
