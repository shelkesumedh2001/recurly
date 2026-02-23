import 'package:hive/hive.dart';

part 'budget.g.dart';

/// Budget settings for tracking spending limits
@HiveType(typeId: 6)
class BudgetSettings extends HiveObject {
  BudgetSettings({
    this.overallMonthlyBudget,
    this.budgetAlertsEnabled = true,
    this.warningThreshold = 0.75,
    Map<String, double>? categoryBudgets,
    this.lastBudgetAlertShown,
  }) : categoryBudgets = categoryBudgets ?? {};

  /// Overall monthly budget limit (null = no limit set)
  @HiveField(0)
  double? overallMonthlyBudget;

  /// Whether to show budget alerts
  @HiveField(1)
  bool budgetAlertsEnabled;

  /// Warning threshold (0.0 to 1.0, default 0.75 = 75%)
  @HiveField(2)
  double warningThreshold;

  /// Per-category budget limits: category ID -> budget limit
  @HiveField(3)
  Map<String, double> categoryBudgets;

  /// Last time a budget alert was shown (to avoid spam)
  @HiveField(4)
  DateTime? lastBudgetAlertShown;

  /// Check if an overall budget is set
  bool get hasBudget => overallMonthlyBudget != null && overallMonthlyBudget! > 0;

  /// Get category budget by category name
  double? getCategoryBudget(String categoryName) {
    return categoryBudgets[categoryName];
  }

  /// Check if category has a budget
  bool hasCategoryBudget(String categoryName) {
    return categoryBudgets.containsKey(categoryName) &&
        categoryBudgets[categoryName]! > 0;
  }

  /// Create copy with updated fields
  BudgetSettings copyWith({
    double? overallMonthlyBudget,
    bool? budgetAlertsEnabled,
    double? warningThreshold,
    Map<String, double>? categoryBudgets,
    DateTime? lastBudgetAlertShown,
    bool clearOverallBudget = false,
    bool clearLastAlert = false,
  }) {
    return BudgetSettings(
      overallMonthlyBudget: clearOverallBudget
          ? null
          : (overallMonthlyBudget ?? this.overallMonthlyBudget),
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      categoryBudgets: categoryBudgets ?? Map.from(this.categoryBudgets),
      lastBudgetAlertShown: clearLastAlert
          ? null
          : (lastBudgetAlertShown ?? this.lastBudgetAlertShown),
    );
  }

  @override
  String toString() {
    return 'BudgetSettings(overall: $overallMonthlyBudget, alerts: $budgetAlertsEnabled, threshold: $warningThreshold, categories: ${categoryBudgets.length})';
  }
}

/// Budget status enum
enum BudgetStatus {
  /// Under budget (below warning threshold)
  safe,

  /// Approaching budget (between warning threshold and 100%)
  warning,

  /// Over budget (100% or more)
  exceeded,

  /// No budget set
  noBudget,
}

extension BudgetStatusExtension on BudgetStatus {
  String get displayName {
    switch (this) {
      case BudgetStatus.safe:
        return 'On Track';
      case BudgetStatus.warning:
        return 'Approaching Limit';
      case BudgetStatus.exceeded:
        return 'Over Budget';
      case BudgetStatus.noBudget:
        return 'No Budget Set';
    }
  }

  String get emoji {
    switch (this) {
      case BudgetStatus.safe:
        return '';
      case BudgetStatus.warning:
        return '';
      case BudgetStatus.exceeded:
        return '';
      case BudgetStatus.noBudget:
        return '';
    }
  }
}
