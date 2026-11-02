import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/exchange_rate.dart';
import '../models/subscription.dart';
import '../services/currency_service.dart';
import '../utils/billing_cycle.dart';
import '../utils/money.dart';
import '../utils/spend_history.dart';
import '../utils/split_copies.dart';
import 'auth_providers.dart';
import 'currency_providers.dart';
import 'household_providers.dart';
import 'subscription_providers.dart';

/// Provider for spending by category (converted to display currency so
/// mixed-currency subscriptions aggregate correctly).
final categorySpendProvider = Provider<Map<SubscriptionCategory, double>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final monthlyCost = ref.watch(myMonthlyCostProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      final Map<SubscriptionCategory, double> spendByCategory = {};

      for (final sub in subscriptions) {
        final converted = monthlyCost(sub);
        final current = spendByCategory[sub.category] ?? 0.0;
        spendByCategory[sub.category] = current + converted;
      }

      return spendByCategory.map((k, v) => MapEntry(k, roundMoney(v)));
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Provider for the most expensive subscription
final mostExpensiveSubscriptionProvider = Provider<Subscription?>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final convertedMonthly = ref.watch(myMonthlyCostProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      if (subscriptions.isEmpty) return null;

      // Ranked by what I pay per month in the display currency, so a
      // foreign-currency sub isn't ranked by its raw number.
      final sorted = List<Subscription>.from(subscriptions)
        ..sort((a, b) => convertedMonthly(b).compareTo(convertedMonthly(a)));

      return sorted.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for yearly projected spend (currency-converted)
final yearlyProjectedSpendProvider = Provider<double>((ref) {
  final monthlySpend = ref.watch(convertedTotalSpendProvider);
  return roundMoney(monthlySpend * 12);
});

/// Provider for category with highest spend
final topCategoryProvider = Provider<MapEntry<SubscriptionCategory, double>?>((ref) {
  final spendByCategory = ref.watch(categorySpendProvider);
  
  if (spendByCategory.isEmpty) return null;

  final sortedEntries = spendByCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sortedEntries.first;
});

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
      final now = clock.now();
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
      final withChanges = subscriptions.where((sub) => sub.hasPriceHistory).toList()
        // Sort by most recent price change date (newest first)
        ..sort((a, b) {
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

/// Pure helper: monthly-equivalent price-change impact converted to
/// [displayCurrency]. Returns `null` if any sub's rate is unresolvable,
/// so callers can render "—" instead of a silently-wrong number.
double? computeTotalPriceChangeImpact({
  required List<Subscription> subs,
  required CurrencyService currencyService,
  required String displayCurrency,
  required ExchangeRateCache? rates,
}) {
  double totalImpact = 0;
  for (final sub in subs) {
    final oldPrice = (sub.lastPriceChange!['price'] as num).toDouble();
    final diff = sub.price - oldPrice;
    // Build a temporary sub with the diff as price so monthlyEquivalent
    // applies the right multiplier (including customDays for custom cycles).
    final monthlyDiff = sub.monthlyEquivalentOf(diff);
    final converted = currencyService.convertOrNull(
      amount: monthlyDiff,
      from: sub.currency,
      to: displayCurrency,
      rates: rates,
    );
    if (converted == null) return null;
    totalImpact += converted;
  }
  return totalImpact;
}

/// Provider for total monthly impact from all price changes (in display
/// currency). Null when rates are unavailable for any sub.
final totalPriceChangeImpactProvider = Provider<double?>((ref) {
  final subs = ref.watch(subscriptionsWithPriceChangesProvider);
  final currencyService = ref.watch(currencyServiceProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final rates = ref.watch(exchangeRatesProvider).value;

  return computeTotalPriceChangeImpact(
    subs: subs,
    currencyService: currencyService,
    displayCurrency: displayCurrency,
    rates: rates,
  );
});

/// Actual bills per month for the past 12 months (incl. this month), split
/// by category and converted to the display currency. Active subs only —
/// archived subs have no recorded end date to stop their history at.
final spendHistoryProvider = Provider<List<MonthSpend>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final rates = ref.watch(exchangeRatesProvider).value;
  final currencyService = ref.watch(currencyServiceProvider);
  final shareOf = ref.watch(myShareOfProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) => computeSpendHistory(
      subscriptions: subscriptions,
      now: clock.now(),
      shareOf: shareOf,
      convert: (amount, from) => currencyService.convert(
        amount: amount,
        from: from,
        to: displayCurrency,
        rates: rates,
      ),
    ),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ============================================================
// Feature 4: Monthly Comparison
// ============================================================

class MonthlyComparison {
  MonthlyComparison({
    required this.currentMonth,
    required this.lastMonth,
    required this.delta,
    this.percentChange,
  });

  final double currentMonth;
  final double lastMonth;
  final double delta;

  /// Null when last month was 0 (a percentage of nothing is meaningless).
  final double? percentChange;
}

final monthlyComparisonProvider = Provider<MonthlyComparison?>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final currencyService = ref.watch(currencyServiceProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final exchangeRates = ref.watch(exchangeRatesProvider).value;
  final shareOf = ref.watch(myShareOfProvider);

  double convert(double amount, String from) => currencyService.convert(
        amount: amount,
        from: from,
        to: displayCurrency,
        rates: exchangeRates,
      );

  return subscriptionsAsync.when(
    data: (subscriptions) {
      if (subscriptions.isEmpty) return null;

      final now = clock.now();
      final thisMonth = DateTime(now.year, now.month, 1);
      final lastMonth = DateTime(now.year, now.month - 1, 1);

      final current = roundMoney(monthSpendRate(
        subscriptions, thisMonth,
        shareOf: shareOf, convert: convert, today: now,
      ),);
      final previous = roundMoney(monthSpendRate(
        subscriptions, lastMonth,
        shareOf: shareOf, convert: convert, today: now,
      ),);

      final delta = roundMoney(current - previous);
      return MonthlyComparison(
        currentMonth: current,
        lastMonth: previous,
        delta: delta,
        // No percentage against nothing — "+$77.48 (0.0%)" read as "no
        // change" (BUG-13).
        percentChange: previous > 0 ? (delta / previous) * 100 : null,
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

final upcomingRenewalsProvider = Provider<List<UpcomingRenewal>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final currencyService = ref.watch(currencyServiceProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final exchangeRates = ref.watch(exchangeRatesProvider).value;

  return subscriptionsAsync.when(
    data: (subscriptions) {
      final now = clock.now();
      final today = DateTime(now.year, now.month, now.day);
      final cutoff = today.add(const Duration(days: 30));
      final List<UpcomingRenewal> renewals = [];

      for (final sub in subscriptions) {
        if (sub.isArchived || sub.deletedAt != null) continue;

        // Anchor on nextBillDate so we honor trial periods AND skip
        // subs added today (their next bill is one cycle out, not today).
        var billDate = sub.nextBillDate;

        // Collect dates within the 30-day window
        while (!billDate.isAfter(cutoff)) {
          final converted = currencyService.convert(
            // What each bill charges — a trial's bills (from trial end)
            // are at the post-trial price, not the trial price (BUG-15).
            amount: sub.chargePerRenewal,
            from: sub.currency,
            to: displayCurrency,
            rates: exchangeRates,
          );
          renewals.add(UpcomingRenewal(
            subscription: sub,
            date: billDate,
            convertedAmount: converted,
          ),);
          billDate = addOneCycle(
            sub.billingCycle,
            billDate,
            customDays: sub.customDays,
          );
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

  final totals = householdSplitTotals(
    ownSubs: ownSubs,
    partnerSubs: partnerSubs,
    myUid: currentUid,
    monthly: (sub) => currencyService.convert(
      amount: sub.monthlyEquivalent,
      from: sub.currency,
      to: displayCurrency,
      rates: exchangeRates,
    ),
  );
  final myTotal = totals.mine;
  final partnerTotal = totals.partner;

  if (myTotal == 0 && partnerTotal == 0) return null;

  return HouseholdSpendComparison(
    myTotal: myTotal,
    partnerTotal: partnerTotal,
  );
});