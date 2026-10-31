import 'dart:math' as math;

import '../models/enums.dart';
import '../models/subscription.dart';
import 'money.dart';

/// Converts [amount] in [from] currency to the display currency.
typedef ConvertToDisplay = double Function(double amount, String from);

/// Where a month sits relative to today.
enum SpendPeriod {
  /// Fully in the past: what was billed. A fact.
  past,

  /// This month: bills already charged plus those still due. Near-certain.
  current,

  /// After this month: what today's subscriptions would bill. An estimate;
  /// subs added, cancelled or repriced later will change it.
  future,
}

/// One bill inside a month.
class MonthBill {
  const MonthBill({
    required this.subscriptionId,
    required this.name,
    required this.category,
    required this.amount,
  });

  final String subscriptionId;
  final String name;
  final SubscriptionCategory category;

  /// Display currency.
  final double amount;
}

/// What was (or would be) billed in one calendar month.
class MonthSpend {
  MonthSpend({
    required this.month,
    required this.year,
    required this.byCategory,
    required this.period,
    this.bills = const [],
  });

  final int month; // 1-12
  final int year;

  /// Display-currency amount per category; categories with no bills are
  /// absent, never zero-valued.
  final Map<SubscriptionCategory, double> byCategory;

  final SpendPeriod period;

  /// The individual bills behind [byCategory].
  final List<MonthBill> bills;

  bool get isCurrentMonth => period == SpendPeriod.current;
  bool get isEstimate => period == SpendPeriod.future;

  double get total => roundMoney(byCategory.values.fold(0, (a, b) => a + b));

  /// Spend for one [category], or the total when [category] is null.
  double amountFor(SubscriptionCategory? category) =>
      category == null ? total : (byCategory[category] ?? 0);
}

/// The price (and its currency) [sub] charged on [date], reconstructed from
/// its price history.
///
/// `priceHistory` is chronological; each entry records the price that was in
/// force *before* the change on `date`. So the first entry dated after
/// [date] holds the price at [date]; if none, the current price applies
/// (always the case for future dates).
({double price, String currency}) priceOn(Subscription sub, DateTime date) {
  if (sub.isFreeTrial) {
    // Trial chains bill only from trial end, at the post-trial price.
    return (price: sub.chargePerRenewal, currency: sub.currency);
  }
  for (final entry in sub.priceHistory ?? const <Map<String, dynamic>>[]) {
    final changedAt = DateTime.tryParse(entry['date'] as String? ?? '');
    final oldPrice = entry['price'];
    if (changedAt == null || oldPrice is! num) continue;
    if (date.isBefore(changedAt)) {
      return (
        price: oldPrice.toDouble(),
        currency: entry['currency'] as String? ?? sub.currency,
      );
    }
  }
  return (price: sub.price, currency: sub.currency);
}

/// Bills per calendar month from [pastMonths] − 1 months before the month
/// containing [now], through [futureMonths] months after it. Oldest first.
///
/// Walks each subscription's real billing chain, so yearly subs spike in
/// their renewal month, weekly subs bill 4 or 5 times, trials bill from
/// trial end and subs starting later bill from their start. Each bill is
/// priced at what it cost (or costs today, for the future).
List<MonthSpend> computeSpendTimeline({
  required List<Subscription> subscriptions,
  required DateTime now,
  required ConvertToDisplay convert,
  int pastMonths = 12,
  int futureMonths = 6,
}) {
  final result = <MonthSpend>[];
  for (var offset = -(pastMonths - 1); offset <= futureMonths; offset++) {
    final start = DateTime(now.year, now.month + offset, 1);
    final end = DateTime(start.year, start.month + 1, 0);
    final byCategory = <SubscriptionCategory, double>{};
    final bills = <MonthBill>[];

    for (final sub in subscriptions) {
      for (final billDate in sub.renewalsInRange(start, end)) {
        final charge = priceOn(sub, billDate);
        if (charge.price <= 0) continue;
        final amount = convert(charge.price, charge.currency);
        byCategory[sub.category] = (byCategory[sub.category] ?? 0) + amount;
        bills.add(
          MonthBill(
            subscriptionId: sub.id,
            name: sub.name,
            category: sub.category,
            amount: amount,
          ),
        );
      }
    }

    result.add(
      MonthSpend(
        month: start.month,
        year: start.year,
        byCategory: byCategory.map((k, v) => MapEntry(k, roundMoney(v))),
        period: offset < 0
            ? SpendPeriod.past
            : offset == 0
                ? SpendPeriod.current
                : SpendPeriod.future,
        bills: bills,
      ),
    );
  }
  return result;
}

/// A coming month expected to cost noticeably more than usual, and why.
class SpendSpike {
  const SpendSpike({
    required this.month,
    required this.amount,
    required this.usual,
    required this.causes,
  });

  final MonthSpend month;
  final double amount;
  final double usual;

  /// The bills that make this month bigger (largest first, at most 2):
  /// subs that bill here but not in every coming month.
  final List<MonthBill> causes;
}

/// Coming months that look clearly above the usual coming month, for
/// [filter] (null = all categories).
///
/// "Usual" is the median of the estimated months, so one yearly renewal
/// doesn't drag the baseline up. A month counts as a spike when it is more
/// than 25% and at least one whole unit above usual — enough that a
/// 5-Thursday month of a weekly sub doesn't qualify on its own.
List<SpendSpike> findSpikes(
  List<MonthSpend> timeline, {
  SubscriptionCategory? filter,
}) {
  final future = timeline.where((m) => m.isEstimate).toList();
  if (future.length < 2) return const [];

  final amounts = [for (final m in future) m.amountFor(filter)]..sort();
  final mid = amounts.length ~/ 2;
  final usual = amounts.length.isOdd
      ? amounts[mid]
      : (amounts[mid - 1] + amounts[mid]) / 2;

  bool inFilter(MonthBill b) => filter == null || b.category == filter;

  // Subs billing in every coming month are the steady base, not a cause.
  final everyMonth = future
      .map((m) => {for (final b in m.bills.where(inFilter)) b.subscriptionId})
      .reduce((a, b) => a.intersection(b));

  final spikes = <SpendSpike>[];
  for (final m in future) {
    final amount = m.amountFor(filter);
    if (amount <= usual * 1.25 || amount - usual < 1) continue;
    // One entry per sub (a weekly sub bills several times a month).
    final bySub = <String, MonthBill>{};
    for (final b in m.bills) {
      if (!inFilter(b) || everyMonth.contains(b.subscriptionId)) continue;
      final prev = bySub[b.subscriptionId];
      bySub[b.subscriptionId] = prev == null
          ? b
          : MonthBill(
              subscriptionId: b.subscriptionId,
              name: b.name,
              category: b.category,
              amount: prev.amount + b.amount,
            );
    }
    final causes = bySub.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (causes.isEmpty) continue;
    spikes.add(
      SpendSpike(
        month: m,
        amount: amount,
        usual: usual,
        causes: causes.sublist(0, math.min(2, causes.length)),
      ),
    );
  }
  return spikes;
}
