import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/utils/money.dart';
import 'package:recurly/utils/spend_history.dart';
import 'package:recurly/utils/split_copies.dart';

/// Group C — analytics consistency (BUG-12, BUG-13, BUG-14, BUG-22).
/// Numbers from the 2026-11-02 test pass (REPORT.md).
const a = 'uidA';
const b = 'uidB';

Subscription _sub(
  String id,
  double price, {
  String owner = a,
  List<Map<String, dynamic>>? splitWith,
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? firstBill,
  DateTime? created,
}) {
  return Subscription(
    id: id,
    name: id,
    price: price,
    billingCycle: cycle,
    firstBillDate: firstBill ?? DateTime(2026, 10, 5),
    category: SubscriptionCategory.entertainment,
    createdAt: created ?? DateTime(2026, 11, 2),
    ownerUid: owner,
    splitWith: splitWith,
  );
}

double identity(double amount, String from) => amount;

void main() {
  group('roundCents / formatMoney (BUG-14, BUG-22)', () {
    test('split shares add up to the price (was 7.75 + 7.75 = 15.50)', () {
      // Same derivation as SplitSubscriptionSheet.
      final partner = roundCents(15.49 * 0.5);
      final mine = roundCents(15.49) - partner;
      expect(formatMoney(partner, r'$'), r'$7.75');
      expect(formatMoney(mine, r'$'), r'$7.74');
      expect(roundCents(partner + mine), 15.49);
    });

    test('a sum that drifted just below the half rounds up', () {
      expect(69.7349999999999.toStringAsFixed(2), '69.73'); // the old card
      expect(roundCents(69.7349999999999), 69.74);
    });

    test('Home 69.74 and the Household card agree (was 69.73)', () {
      const raw = 69.7349999999999; // how the card's sum came out
      expect(formatMoney(raw, r'$'), r'$69.74');
      expect(roundMoney(raw), 69.74);
    });

    test('real fractions of a cent are untouched', () {
      expect(roundCents(1.004), 1.0);
      expect(roundCents(1.006), 1.01);
    });

    test('thousands separators and negatives', () {
      expect(formatMoney(999999.99, r'$'), r'$999,999.99');
      expect(formatMoney(1500, '₹'), '₹1,500.00');
      expect(formatMoney(-2.01, r'$'), r'-$2.01');
      expect(formatMoney(1234.4, '¥', currencyCode: 'JPY'), '¥1,234');
    });

    test('CSV yearly = Analytics yearly (round monthly, then x12)', () {
      const monthly = 158.1985; // unrounded sum
      final analyticsYearly = roundMoney(roundMoney(monthly) * 12);
      expect(analyticsYearly, 1898.4);
      expect(formatMoney(roundMoney(roundMoney(monthly) * 12), r'$'),
          r'$1,898.40',);
    });

    test('Subscription.formatAmount uses it', () {
      final s = _sub('x', 999999.99);
      expect(s.formattedPrice, r'$999,999.99');
    });
  });

  group('what I pay, owner and partner alike (BUG-12, D2)', () {
    // H2: A owns Netflix 15.49 split 50% with B; A also has Spotify 11.99,
    // iCloud 120/y, Gym 40. B has YouTube 22.99 + Disney 9.99 + A's copy.
    final netflix = _sub('netflix', 15.49, splitWith: [
      {'uid': b, 'sharePercent': 50, 'accepted': true},
    ],);
    final aSubs = [
      netflix,
      _sub('spotify', 11.99),
      _sub('icloud', 120, cycle: BillingCycle.yearly),
      _sub('gym', 40),
    ];
    final bSubs = [
      _sub('youtube', 22.99, owner: b),
      _sub('disney', 9.99, owner: b),
      partnerCopyFor(netflix, ownerUid: a, myUid: b)!,
    ];

    double total(List<Subscription> subs, String uid) => subs.fold(
          0,
          (sum, s) => sum + s.monthlyEquivalent * myShareFraction(s, uid),
        );

    test('A 69.74 (= Home My share), B 40.73, sum = household 110.46', () {
      expect(roundMoney(total(aSubs, a)), 69.74);
      expect(roundMoney(total(bSubs, b)), 40.73);
      expect(roundMoney(total(aSubs, a) + total(bSubs, b)), 110.46);
    });

    test('Spending over time counts my share of each bill', () {
      final history = computeSpendHistory(
        subscriptions: [netflix],
        now: DateTime(2026, 11, 20),
        convert: identity,
        months: 1,
        shareOf: (s) => myShareFraction(s, a),
      );
      expect(history.single.total, 7.75); // 15.49 / 2, rounded to cents
    });
  });

  group('monthSpendRate — last month (BUG-13)', () {
    double share(Subscription s) => 1;

    test('a sub added today whose last bill was in October counts in '
        'October', () {
      final sub = _sub('n', 15.49, firstBill: DateTime(2026, 10, 3));
      expect(
        monthSpendRate([sub], DateTime(2026, 10),
            shareOf: share, convert: identity,),
        closeTo(15.49, 1e-9),
      );
    });

    test('nothing before its first bill', () {
      final sub = _sub('n', 15.49, firstBill: DateTime(2026, 11, 3));
      expect(
        monthSpendRate([sub], DateTime(2026, 10),
            shareOf: share, convert: identity,),
        0,
      );
    });

    test('last month priced from price history', () {
      final sub = _sub('n', 17.99, firstBill: DateTime(2026, 9, 3)).copyWith(
        priceHistory: [
          {'price': 15.49, 'currency': 'USD', 'date': '2026-11-01T10:00:00.000'},
        ],
      );
      expect(
        monthSpendRate([sub], DateTime(2026, 10),
            shareOf: share, convert: identity,),
        closeTo(15.49, 1e-9),
      );
      expect(
        monthSpendRate([sub], DateTime(2026, 11),
            shareOf: share, convert: identity,),
        closeTo(17.99, 1e-9),
      );
    });

    test('a running trial counts its trial price once it exists', () {
      final trial = Subscription(
        id: 't',
        name: 't',
        price: 15,
        billingCycle: BillingCycle.monthly,
        firstBillDate: DateTime(2026, 11, 9),
        category: SubscriptionCategory.productivity,
        createdAt: DateTime(2026, 11, 2),
        isFreeTrial: true,
        trialEndDate: DateTime(2026, 12, 9),
        priceAfterTrial: 12.99,
      );
      expect(
        monthSpendRate([trial], DateTime(2026, 10),
            shareOf: share, convert: identity,),
        0,
      );
      expect(
        monthSpendRate([trial], DateTime(2026, 11),
            shareOf: share, convert: identity,),
        15,
      );
    });

    test('this month: a trial ending later this month still counts its '
        'trial price, like the hero', () {
      final trial = Subscription(
        id: 't',
        name: 't',
        price: 0,
        billingCycle: BillingCycle.monthly,
        firstBillDate: DateTime(2026, 11, 16),
        category: SubscriptionCategory.productivity,
        createdAt: DateTime(2026, 11, 2),
        isFreeTrial: true,
        trialEndDate: DateTime(2026, 11, 16),
        priceAfterTrial: 9.99,
      );
      final today = DateTime(2026, 11, 10);
      expect(
        monthSpendRate([trial], DateTime(2026, 11),
            shareOf: share, convert: identity, today: today,),
        0,
      );
      // After it ended, the post-trial price — again like the hero.
      expect(
        monthSpendRate([trial], DateTime(2026, 11),
            shareOf: share, convert: identity, today: DateTime(2026, 11, 17),),
        9.99,
      );
    });
  });
}
