import '../models/custom_category.dart';
import '../models/subscription.dart';
import 'money.dart';

/// Converts [amount] in [from] currency to the display currency.
typedef ConvertToDisplay = double Function(double amount, String from);

/// What was billed in one calendar month, split by category.
class MonthSpend {
  MonthSpend({
    required this.month,
    required this.year,
    required this.byCategory,
    required this.isCurrentMonth,
  });

  final int month; // 1-12
  final int year;

  /// Display-currency amount per category; categories with no bills are
  /// absent, never zero-valued.
  final Map<UnifiedCategory, double> byCategory;

  /// The current month counts bills still due later this month too, so the
  /// bar reads as "this month's bill", not a half-finished month.
  final bool isCurrentMonth;

  double get total => roundMoney(byCategory.values.fold(0, (a, b) => a + b));

  /// Spend for one [category], or the total when [category] is null.
  double amountFor(UnifiedCategory? category) =>
      category == null ? total : (byCategory[category] ?? 0);
}

/// The price (and its currency) [sub] charged on [date], reconstructed from
/// its price history.
///
/// `priceHistory` is chronological; each entry records the price that was in
/// force *before* the change on `date`. So the first entry dated after
/// [date] holds the price at [date]; if none, the current price applies.
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

/// Actual bills per calendar month for the [months] months ending with the
/// month containing [now], oldest first.
///
/// Walks each subscription's real billing chain (so yearly subs spike in
/// their renewal month, weekly subs bill 4 or 5 times) and prices each bill
/// at what it cost on that day. Bills before a subscription's first bill
/// date don't exist, so history starts where the user's data does.
List<MonthSpend> computeSpendHistory({
  required List<Subscription> subscriptions,
  required DateTime now,
  required ConvertToDisplay convert,
  int months = 12,
  double Function(Subscription sub)? shareOf,
  UnifiedCategory Function(Subscription sub)? categoryOf,
}) {
  final categoryFor =
      categoryOf ?? (Subscription s) => UnifiedCategory.fromEnum(s.category);
  final result = <MonthSpend>[];
  for (var i = months - 1; i >= 0; i--) {
    final start = DateTime(now.year, now.month - i, 1);
    final end = DateTime(start.year, start.month + 1, 0);
    final byCategory = <UnifiedCategory, double>{};

    for (final sub in subscriptions) {
      for (final billDate in sub.renewalsInRange(start, end)) {
        final charge = priceOn(sub, billDate);
        if (charge.price <= 0) continue;
        // My share of the bill (D2); 1 for unsplit subs.
        final share = shareOf?.call(sub) ?? 1;
        final category = categoryFor(sub);
        byCategory[category] = (byCategory[category] ?? 0) +
            convert(charge.price * share, charge.currency);
      }
    }

    result.add(
      MonthSpend(
        month: start.month,
        year: start.year,
        byCategory: byCategory.map((k, v) => MapEntry(k, roundMoney(v))),
        isCurrentMonth: i == 0,
      ),
    );
  }
  return result;
}

/// What I paid per month (monthly-equivalent, my share, display currency)
/// for subs that were billing in [targetMonth].
///
/// "Billing" follows the same chain as Spending over time — from the first
/// bill (trial end for trials), priced as of that month via price history —
/// not `createdAt`: a sub added today whose last bill was in October did
/// cost something in October (BUG-13).
double monthSpendRate(
  List<Subscription> subscriptions,
  DateTime targetMonth, {
  required double Function(Subscription) shareOf,
  required double Function(double amount, String from) convert,
  DateTime? today,
}) {
  final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
  // "Still in its trial?" is judged today for the current month — the same
  // moment the hero total uses — and at month end for past months.
  final asOf = today != null && today.isBefore(endOfMonth)
      ? DateTime(today.year, today.month, today.day)
      : endOfMonth;
  final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);

  double total = 0;
  for (final sub in subscriptions) {
    if (sub.deletedAt != null && sub.deletedAt!.isBefore(startOfMonth)) continue;
    if (sub.isArchived) continue;

    final trialEnd = sub.isFreeTrial ? sub.trialEndDate : null;
    final ({double price, String currency}) charge;
    if (trialEnd != null &&
        DateTime(trialEnd.year, trialEnd.month, trialEnd.day)
            .isAfter(asOf)) {
      // Still in its trial that month: the trial price, once it existed
      // (same as the hero counts a running trial).
      if (sub.createdAt.isAfter(endOfMonth)) continue;
      charge = (price: sub.price, currency: sub.currency);
    } else {
      final firstBill = trialEnd ?? sub.firstBillDate;
      final firstBillDay =
          DateTime(firstBill.year, firstBill.month, firstBill.day);
      if (firstBillDay.isAfter(endOfMonth)) continue;
      charge = priceOn(sub, endOfMonth);
    }
    total += convert(
      sub.monthlyEquivalentOf(charge.price) * shareOf(sub),
      charge.currency,
    );
  }
  return total;
}
