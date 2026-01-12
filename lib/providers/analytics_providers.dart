import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/subscription.dart';
import 'subscription_providers.dart';

/// Provider for spending by category
final categorySpendProvider = Provider<Map<SubscriptionCategory, double>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      final Map<SubscriptionCategory, double> spendByCategory = {};

      for (final sub in subscriptions) {
        final current = spendByCategory[sub.category] ?? 0.0;
        spendByCategory[sub.category] = current + sub.monthlyEquivalent;
      }

      return spendByCategory;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Provider for the most expensive subscription
final mostExpensiveSubscriptionProvider = Provider<Subscription?>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      if (subscriptions.isEmpty) return null;
      
      // Sort by monthly equivalent cost
      final sorted = List<Subscription>.from(subscriptions)
        ..sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));
      
      return sorted.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for yearly projected spend
final yearlyProjectedSpendProvider = Provider<double>((ref) {
  final monthlySpend = ref.watch(totalMonthlySpendProvider);
  return monthlySpend * 12;
});

/// Provider for category with highest spend
final topCategoryProvider = Provider<MapEntry<SubscriptionCategory, double>?>((ref) {
  final spendByCategory = ref.watch(categorySpendProvider);
  
  if (spendByCategory.isEmpty) return null;

  final sortedEntries = spendByCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sortedEntries.first;
});

/// Data class for monthly spending projection
class MonthlySpendingData {
  MonthlySpendingData(this.month, this.year, this.amount);

  final int month; // 1-12
  final int year;
  final double amount;
}

/// Provider for projected monthly spending for the next 12 months
final spendingTrendProvider = Provider<List<MonthlySpendingData>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      final now = DateTime.now();
      final List<MonthlySpendingData> trendData = [];

      // Calculate for next 6 months
      for (int i = 0; i < 6; i++) {
        final targetDate = DateTime(now.year, now.month + i, 1);
        double monthlyTotal = 0;

        for (final sub in subscriptions) {
          final amount = _calculateMonthlyAmount(sub, targetDate);
          monthlyTotal += amount;
        }
        trendData.add(MonthlySpendingData(targetDate.month, targetDate.year, monthlyTotal));
      }

      return trendData;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Calculate how much a subscription will cost in a specific month
double _calculateMonthlyAmount(Subscription sub, DateTime targetMonth) {
  final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
  final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);

  switch (sub.billingCycle) {
    case BillingCycle.monthly:
      // Monthly subscriptions bill once per month
      return sub.price;

    case BillingCycle.yearly:
      // Yearly subscriptions: check if anniversary falls in this month
      if (_willBillInMonth(sub, targetMonth)) {
        return sub.price;
      }
      return 0;

    case BillingCycle.weekly:
      // Weekly subscriptions: count how many times it bills in this month
      var currentBillDate = sub.firstBillDate;

      // Fast forward to near the target month
      final daysDiff = targetMonth.difference(currentBillDate).inDays;
      if (daysDiff > 0) {
        final weeksPassed = daysDiff ~/ 7;
        currentBillDate = currentBillDate.add(Duration(days: weeksPassed * 7));
      }

      // Go back a bit to ensure we don't miss any
      currentBillDate = currentBillDate.subtract(const Duration(days: 28));

      // Count billings in this month
      int billingCount = 0;
      for (int i = 0; i < 6; i++) {
        if (currentBillDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))) &&
            currentBillDate.isBefore(lastDayOfMonth.add(const Duration(days: 1)))) {
          billingCount++;
        }
        currentBillDate = currentBillDate.add(const Duration(days: 7));
      }

      return sub.price * billingCount;

    case BillingCycle.custom:
      // Custom is treated as monthly
      return sub.price;
  }
}

/// Helper to check if a subscription bills in a specific month
bool _willBillInMonth(Subscription sub, DateTime targetMonth) {
  // Calculate the first and last day of the target month
  final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
  final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);

  switch (sub.billingCycle) {
    case BillingCycle.monthly:
      // Monthly subscriptions always bill every month
      return true;

    case BillingCycle.yearly:
      // Yearly subscriptions bill once per year on the same month/day
      // Check if the billing anniversary falls in this target month
      var billingDate = DateTime(
        targetMonth.year,
        sub.firstBillDate.month,
        sub.firstBillDate.day,
      );

      // If the billing date is before the subscription started, try next year
      if (billingDate.isBefore(sub.firstBillDate)) {
        billingDate = DateTime(
          targetMonth.year + 1,
          sub.firstBillDate.month,
          sub.firstBillDate.day,
        );
      }

      // Check if this billing date falls within the target month
      return billingDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))) &&
          billingDate.isBefore(lastDayOfMonth.add(const Duration(days: 1)));

    case BillingCycle.weekly:
      // Weekly subscriptions: check if any billing date falls in target month
      // Start from the first bill date
      var currentBillDate = sub.firstBillDate;

      // Fast forward to target month (approximately)
      final daysDiff = targetMonth.difference(currentBillDate).inDays;
      if (daysDiff > 0) {
        final weeksPassed = daysDiff ~/ 7;
        currentBillDate = currentBillDate.add(Duration(days: weeksPassed * 7));
      }

      // Check if any weekly billing falls in the target month
      // (Go back a few weeks to be safe, then check forward)
      currentBillDate = currentBillDate.subtract(const Duration(days: 28));

      for (int i = 0; i < 6; i++) { // Check 6 weeks worth
        if (currentBillDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))) &&
            currentBillDate.isBefore(lastDayOfMonth.add(const Duration(days: 1)))) {
          return true; // At least one billing falls in this month
        }
        currentBillDate = currentBillDate.add(const Duration(days: 7));
      }
      return false;

    case BillingCycle.custom:
      // Custom is treated as monthly for now
      return true;
  }
}