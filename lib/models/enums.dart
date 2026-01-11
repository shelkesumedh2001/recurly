import 'package:hive/hive.dart';

part 'enums.g.dart';

/// Billing cycle options for subscriptions
@HiveType(typeId: 1)
enum BillingCycle {
  @HiveField(0)
  monthly,

  @HiveField(1)
  yearly,

  @HiveField(2)
  weekly,

  @HiveField(3)
  custom;

  String get displayName {
    switch (this) {
      case BillingCycle.monthly:
        return 'Monthly';
      case BillingCycle.yearly:
        return 'Yearly';
      case BillingCycle.weekly:
        return 'Weekly';
      case BillingCycle.custom:
        return 'Custom';
    }
  }

  /// Calculate monthly equivalent for comparison
  double getMonthlyMultiplier() {
    switch (this) {
      case BillingCycle.monthly:
        return 1.0;
      case BillingCycle.yearly:
        return 1.0 / 12.0;
      case BillingCycle.weekly:
        return 52.0 / 12.0; // ~4.33
      case BillingCycle.custom:
        return 1.0; // Default to monthly
    }
  }

  /// Get days until next billing
  int getDaysInCycle() {
    switch (this) {
      case BillingCycle.monthly:
        return 30; // Approximate
      case BillingCycle.yearly:
        return 365;
      case BillingCycle.weekly:
        return 7;
      case BillingCycle.custom:
        return 30; // Default
    }
  }
}

/// Subscription categories for organization
@HiveType(typeId: 2)
enum SubscriptionCategory {
  @HiveField(0)
  entertainment,

  @HiveField(1)
  utilities,

  @HiveField(2)
  health,

  @HiveField(3)
  finance,

  @HiveField(4)
  productivity,

  @HiveField(5)
  other;

  String get displayName {
    switch (this) {
      case SubscriptionCategory.entertainment:
        return 'Entertainment';
      case SubscriptionCategory.utilities:
        return 'Utilities';
      case SubscriptionCategory.health:
        return 'Health & Fitness';
      case SubscriptionCategory.finance:
        return 'Finance';
      case SubscriptionCategory.productivity:
        return 'Productivity';
      case SubscriptionCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case SubscriptionCategory.entertainment:
        return '🎬';
      case SubscriptionCategory.utilities:
        return '⚡';
      case SubscriptionCategory.health:
        return '❤️';
      case SubscriptionCategory.finance:
        return '💰';
      case SubscriptionCategory.productivity:
        return '📊';
      case SubscriptionCategory.other:
        return '📦';
    }
  }
}
