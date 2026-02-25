import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/subscription.dart';
import 'auth_providers.dart';
import 'currency_providers.dart';
import 'household_providers.dart';
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

/// Data class for subscription count over time
class SubscriptionCountData {
  SubscriptionCountData(this.month, this.year, this.count);

  final int month; // 1-12
  final int year;
  final int count;
}

/// Provider for subscription count over time (past 12 months)
final subscriptionCountOverTimeProvider = Provider<List<SubscriptionCountData>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      final now = DateTime.now();
      final List<SubscriptionCountData> countData = [];

      for (int i = 11; i >= 0; i--) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        final endOfMonth = DateTime(targetDate.year, targetDate.month + 1, 0, 23, 59, 59);

        // Count subs created on or before end of this month (and not deleted before it)
        int count = 0;
        for (final sub in subscriptions) {
          if (!sub.createdAt.isAfter(endOfMonth)) {
            // If sub was soft-deleted before this month ended, don't count it
            if (sub.deletedAt != null && sub.deletedAt!.isBefore(DateTime(targetDate.year, targetDate.month, 1))) {
              continue;
            }
            count++;
          }
        }

        countData.add(SubscriptionCountData(targetDate.month, targetDate.year, count));
      }

      return countData;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for subscriptions with price changes, sorted by most recent change
final subscriptionsWithPriceChangesProvider = Provider<List<Subscription>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      final withChanges = subscriptions.where((sub) => sub.hasPriceHistory).toList();
      // Sort by most recent price change date (newest first)
      withChanges.sort((a, b) {
        final aDate = DateTime.parse(a.lastPriceChange!['date'] as String);
        final bDate = DateTime.parse(b.lastPriceChange!['date'] as String);
        return bDate.compareTo(aDate);
      });
      return withChanges;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for total monthly impact from all price changes
final totalPriceChangeImpactProvider = Provider<double>((ref) {
  final subs = ref.watch(subscriptionsWithPriceChangesProvider);

  double totalImpact = 0;
  for (final sub in subs) {
    // Impact = difference in monthly equivalent between current and last recorded price
    final oldPrice = (sub.lastPriceChange!['price'] as num).toDouble();
    final diff = sub.price - oldPrice;
    totalImpact += diff * sub.billingCycle.getMonthlyMultiplier();
  }
  return totalImpact;
});

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

// ============================================================
// Feature 4: Monthly Comparison
// ============================================================

class MonthlyComparison {
  MonthlyComparison({
    required this.currentMonth,
    required this.lastMonth,
    required this.delta,
    required this.percentChange,
  });

  final double currentMonth;
  final double lastMonth;
  final double delta;
  final double percentChange;
}

/// Computes monthly spend for a target month using monthlyEquivalent
/// (stable, no yearly billing spikes) with currency conversion.
double _computeMonthSpend(
  List<Subscription> subscriptions,
  DateTime targetMonth, {
  required String displayCurrency,
  required dynamic currencyService,
  required dynamic exchangeRates,
}) {
  final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);
  final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);

  double total = 0;
  for (final sub in subscriptions) {
    // Sub must have been created by end of target month
    if (sub.createdAt.isAfter(endOfMonth)) continue;
    // Sub must not have been deleted before start of target month
    if (sub.deletedAt != null && sub.deletedAt!.isBefore(startOfMonth)) continue;
    if (sub.isArchived) continue;

    total += currencyService.convert(
      amount: sub.monthlyEquivalent,
      from: sub.currency,
      to: displayCurrency,
      rates: exchangeRates,
    );
  }
  return total;
}

final monthlyComparisonProvider = Provider<MonthlyComparison?>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final currencyService = ref.watch(currencyServiceProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final exchangeRates = ref.watch(exchangeRatesProvider).value;

  return subscriptionsAsync.when(
    data: (subscriptions) {
      if (subscriptions.isEmpty) return null;

      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);
      final lastMonth = DateTime(now.year, now.month - 1, 1);

      final current = _computeMonthSpend(
        subscriptions, thisMonth,
        displayCurrency: displayCurrency,
        currencyService: currencyService,
        exchangeRates: exchangeRates,
      );
      final previous = _computeMonthSpend(
        subscriptions, lastMonth,
        displayCurrency: displayCurrency,
        currencyService: currencyService,
        exchangeRates: exchangeRates,
      );

      final delta = current - previous;
      final percentChange = previous > 0 ? (delta / previous) * 100 : 0.0;

      return MonthlyComparison(
        currentMonth: current,
        lastMonth: previous,
        delta: delta,
        percentChange: percentChange,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// ============================================================
// Feature 5: Upcoming Renewals (30-day forecast)
// ============================================================

class UpcomingRenewal {
  UpcomingRenewal({
    required this.subscription,
    required this.date,
    required this.convertedAmount,
  });

  final Subscription subscription;
  final DateTime date;
  final double convertedAmount;
}

/// Add one billing cycle to a date (mirrors Subscription._addBillingCycle)
DateTime _addOneCycle(BillingCycle cycle, DateTime date) {
  switch (cycle) {
    case BillingCycle.monthly:
      return DateTime(date.year, date.month + 1, date.day);
    case BillingCycle.yearly:
      return DateTime(date.year + 1, date.month, date.day);
    case BillingCycle.weekly:
      return date.add(const Duration(days: 7));
    case BillingCycle.custom:
      return DateTime(date.year, date.month + 1, date.day);
  }
}

final upcomingRenewalsProvider = Provider<List<UpcomingRenewal>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final currencyService = ref.watch(currencyServiceProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final exchangeRates = ref.watch(exchangeRatesProvider).value;

  return subscriptionsAsync.when(
    data: (subscriptions) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cutoff = today.add(const Duration(days: 30));
      final List<UpcomingRenewal> renewals = [];

      for (final sub in subscriptions) {
        if (sub.isArchived || sub.deletedAt != null) continue;

        // Find all billing dates within the next 30 days
        var billDate = sub.firstBillDate;

        // Fast forward to around now
        while (billDate.isBefore(today)) {
          billDate = _addOneCycle(sub.billingCycle, billDate);
        }

        // Collect dates within the 30-day window
        while (!billDate.isAfter(cutoff)) {
          final converted = currencyService.convert(
            amount: sub.price,
            from: sub.currency,
            to: displayCurrency,
            rates: exchangeRates,
          );
          renewals.add(UpcomingRenewal(
            subscription: sub,
            date: billDate,
            convertedAmount: converted,
          ));
          billDate = _addOneCycle(sub.billingCycle, billDate);
        }
      }

      // Sort by date, cap at 20
      renewals.sort((a, b) => a.date.compareTo(b.date));
      return renewals.take(20).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// ============================================================
// Feature 7: Split Savings
// ============================================================

class SplitSavings {
  SplitSavings({
    required this.monthlySavings,
    required this.yearlySavings,
    required this.splitCount,
  });

  final double monthlySavings;
  final double yearlySavings;
  final int splitCount;
}

final splitSavingsProvider = Provider<SplitSavings?>((ref) {
  final isInHousehold = ref.watch(isInHouseholdProvider);
  if (!isInHousehold) return null;

  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final currentUid = ref.watch(currentFirebaseUserProvider)?.uid;
  final currencyService = ref.watch(currencyServiceProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final exchangeRates = ref.watch(exchangeRatesProvider).value;

  return subscriptionsAsync.when(
    data: (subscriptions) {
      double totalSavings = 0;
      int splitCount = 0;

      for (final sub in subscriptions) {
        // Skip reference subs
        if (sub.ownerUid != null && sub.ownerUid != currentUid) continue;
        if (sub.splitWith == null || sub.splitWith!.isEmpty) continue;

        double partnerShareTotal = 0;
        for (final split in sub.splitWith!) {
          if (split['accepted'] == true) {
            partnerShareTotal += (split['sharePercent'] as num).toDouble();
          }
        }

        if (partnerShareTotal > 0) {
          final savings = sub.monthlyEquivalent * (partnerShareTotal / 100);
          totalSavings += currencyService.convert(
            amount: savings,
            from: sub.currency,
            to: displayCurrency,
            rates: exchangeRates,
          );
          splitCount++;
        }
      }

      if (splitCount == 0) return null;

      return SplitSavings(
        monthlySavings: totalSavings,
        yearlySavings: totalSavings * 12,
        splitCount: splitCount,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// ============================================================
// Feature 8: Household Spend Comparison
// ============================================================

class HouseholdSpendComparison {
  HouseholdSpendComparison({
    required this.myTotal,
    required this.partnerTotal,
  });

  final double myTotal;
  final double partnerTotal;

  double get total => myTotal + partnerTotal;
  double get myPercent => total > 0 ? myTotal / total : 0.5;
  double get partnerPercent => total > 0 ? partnerTotal / total : 0.5;
}

final householdSpendComparisonProvider = Provider<HouseholdSpendComparison?>((ref) {
  final isInHousehold = ref.watch(isInHouseholdProvider);
  if (!isInHousehold) return null;

  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final partnerSubsAsync = ref.watch(partnerSubscriptionsProvider);
  final currentUid = ref.watch(currentFirebaseUserProvider)?.uid;
  final currencyService = ref.watch(currencyServiceProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final exchangeRates = ref.watch(exchangeRatesProvider).value;

  final ownSubs = subscriptionsAsync.value ?? [];
  final partnerSubs = partnerSubsAsync.value ?? [];

  if (ownSubs.isEmpty && partnerSubs.isEmpty) return null;

  // My total: apply split multipliers (same as _convertedMyShare)
  double myTotal = 0;
  double partnerFromSplits = 0;
  for (final sub in ownSubs) {
    // Skip reference subs
    if (sub.ownerUid != null && sub.ownerUid != currentUid) continue;
    if (sub.isArchived || sub.deletedAt != null) continue;

    double myMultiplier = 1.0;
    if (sub.splitWith != null) {
      for (final split in sub.splitWith!) {
        if (split['accepted'] == true) {
          final partnerShare = (split['sharePercent'] as num).toDouble();
          myMultiplier -= partnerShare / 100;
          // Track what partner pays from my subs
          partnerFromSplits += currencyService.convert(
            amount: sub.monthlyEquivalent * (partnerShare / 100),
            from: sub.currency,
            to: displayCurrency,
            rates: exchangeRates,
          );
        }
      }
    }
    myTotal += currencyService.convert(
      amount: sub.monthlyEquivalent * myMultiplier,
      from: sub.currency,
      to: displayCurrency,
      rates: exchangeRates,
    );
  }

  // Partner total: their own subs + what they split from my subs
  double partnerOwn = 0;
  for (final sub in partnerSubs) {
    // Skip references back to our subs
    if (sub.ownerUid == currentUid) continue;
    if (sub.isArchived || sub.deletedAt != null) continue;

    partnerOwn += currencyService.convert(
      amount: sub.monthlyEquivalent,
      from: sub.currency,
      to: displayCurrency,
      rates: exchangeRates,
    );
  }

  final partnerTotal = partnerOwn + partnerFromSplits;

  if (myTotal == 0 && partnerTotal == 0) return null;

  return HouseholdSpendComparison(
    myTotal: myTotal,
    partnerTotal: partnerTotal,
  );
});