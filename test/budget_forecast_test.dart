import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/providers/budget_providers.dart';

/// Mid-month so the forecast has both past (billed) and future (upcoming)
/// days to split around. July has 31 days.
final _today = DateTime(2026, 7, 15);

Subscription sub({
  required String id,
  double price = 100,
  String currency = 'USD',
  BillingCycle cycle = BillingCycle.monthly,
  required DateTime firstBillDate,
  int? customDays,
  bool isArchived = false,
  DateTime? deletedAt,
  bool isFreeTrial = false,
  DateTime? trialEndDate,
  double? priceAfterTrial,
}) {
  return Subscription(
    id: id,
    name: id,
    price: price,
    currency: currency,
    billingCycle: cycle,
    firstBillDate: firstBillDate,
    category: SubscriptionCategory.entertainment,
    createdAt: firstBillDate,
    customDays: customDays,
    isArchived: isArchived,
    deletedAt: deletedAt,
    isFreeTrial: isFreeTrial,
    trialEndDate: trialEndDate,
    priceAfterTrial: priceAfterTrial,
  );
}

void main() {
  group('Subscription.renewalsInRange', () {
    final monthStart = DateTime(2026, 7, 1);
    final monthEnd = DateTime(2026, 7, 31);

    test('monthly sub anchored in the past bills once this month, on its day',
        () {
      final s = sub(id: 's', firstBillDate: DateTime(2025, 3, 20));
      final dates = s.renewalsInRange(monthStart, monthEnd);
      expect(dates, [DateTime(2026, 7, 20)]);
    });

    test('sub starting mid-month counts its initial charge', () {
      final s = sub(id: 's', firstBillDate: DateTime(2026, 7, 10));
      expect(s.renewalsInRange(monthStart, monthEnd), [DateTime(2026, 7, 10)]);
    });

    test('yearly sub only bills in its renewal month', () {
      final s = sub(
        id: 's',
        cycle: BillingCycle.yearly,
        firstBillDate: DateTime(2024, 7, 8),
      );
      expect(s.renewalsInRange(monthStart, monthEnd), [DateTime(2026, 7, 8)]);
      // A different month sees nothing.
      expect(
        s.renewalsInRange(DateTime(2026, 8, 1), DateTime(2026, 8, 31)),
        isEmpty,
      );
    });

    test('weekly sub bills every 7 days across the month', () {
      final s = sub(
        id: 's',
        cycle: BillingCycle.weekly,
        firstBillDate: DateTime(2026, 7, 1),
      );
      expect(
        s.renewalsInRange(monthStart, monthEnd),
        [
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 8),
          DateTime(2026, 7, 15),
          DateTime(2026, 7, 22),
          DateTime(2026, 7, 29),
        ],
      );
    });

    test('custom-days sub bills on its own cadence', () {
      final s = sub(
        id: 's',
        cycle: BillingCycle.custom,
        customDays: 10,
        firstBillDate: DateTime(2026, 7, 3),
      );
      expect(
        s.renewalsInRange(monthStart, monthEnd),
        [DateTime(2026, 7, 3), DateTime(2026, 7, 13), DateTime(2026, 7, 23)],
      );
    });

    test('free trial anchors its first charge on the trial-end date', () {
      final s = sub(
        id: 's',
        isFreeTrial: true,
        trialEndDate: DateTime(2026, 7, 18),
        priceAfterTrial: 299,
        firstBillDate: DateTime(2026, 7, 4), // ignored for trials
      );
      expect(s.renewalsInRange(monthStart, monthEnd), [DateTime(2026, 7, 18)]);
    });

    test('sub whose next bill is next month contributes nothing', () {
      final s = sub(id: 's', firstBillDate: DateTime(2026, 8, 5));
      expect(s.renewalsInRange(monthStart, monthEnd), isEmpty);
    });
  });

  group('Subscription.chargePerRenewal', () {
    test('normal sub charges its price', () {
      expect(sub(id: 's', price: 49, firstBillDate: _today).chargePerRenewal,
          49,);
    });

    test('trial charges the post-trial price', () {
      final s = sub(
        id: 's',
        price: 0,
        isFreeTrial: true,
        trialEndDate: _today,
        priceAfterTrial: 149,
        firstBillDate: _today,
      );
      expect(s.chargePerRenewal, 149);
    });

    test('free trial with no post-trial price charges nothing', () {
      final s = sub(
        id: 's',
        price: 0,
        isFreeTrial: true,
        trialEndDate: _today,
        firstBillDate: _today,
      );
      expect(s.chargePerRenewal, 0);
    });
  });

  group('BudgetForecast.forMonth', () {
    BudgetForecast run(List<Subscription> subs) => BudgetForecast.forMonth(
          subscriptions: subs,
          today: _today,
          // Identity conversion — currency handling is tested elsewhere.
          convertedCharge: (s) => s.chargePerRenewal,
        );

    test('splits charges into billed-so-far and upcoming around today', () {
      // Monthly on the 5th (billed) + monthly on the 20th (upcoming).
      final forecast = run([
        sub(id: 'past', price: 649, firstBillDate: DateTime(2026, 1, 5)),
        sub(id: 'future', price: 199, firstBillDate: DateTime(2026, 1, 20)),
      ]);
      expect(forecast.billedSoFar, 649);
      expect(forecast.upcoming, 199);
      expect(forecast.upcomingCount, 1);
      expect(forecast.projected, 848);
    });

    test('a charge landing exactly today counts as billed, not upcoming', () {
      final forecast =
          run([sub(id: 's', price: 50, firstBillDate: DateTime(2026, 3, 15))]);
      expect(forecast.billedSoFar, 50);
      expect(forecast.upcoming, 0);
      expect(forecast.upcomingCount, 0);
    });

    test('annual renewal counts in full in its month', () {
      final forecast = run([
        sub(
          id: 'annual',
          price: 11988,
          cycle: BillingCycle.yearly,
          firstBillDate: DateTime(2024, 7, 20),
        ),
      ]);
      expect(forecast.upcoming, 11988);
      expect(forecast.upcomingCount, 1);
      expect(forecast.projected, 11988);
    });

    test('archived and soft-deleted subs are excluded', () {
      final forecast = run([
        sub(id: 'ok', price: 100, firstBillDate: DateTime(2026, 1, 10)),
        sub(
          id: 'archived',
          price: 999,
          firstBillDate: DateTime(2026, 1, 10),
          isArchived: true,
        ),
        sub(
          id: 'deleted',
          price: 999,
          firstBillDate: DateTime(2026, 1, 10),
          deletedAt: DateTime(2026, 6, 1),
        ),
      ]);
      expect(forecast.billedSoFar, 100);
    });

    test('free trials with no charge are skipped', () {
      final forecast = run([
        sub(
          id: 'trial',
          price: 0,
          isFreeTrial: true,
          trialEndDate: DateTime(2026, 7, 25),
          firstBillDate: DateTime(2026, 7, 25),
        ),
      ]);
      expect(forecast.upcoming, 0);
      expect(forecast.upcomingCount, 0);
    });

    test('a converting trial shows up as an upcoming charge', () {
      final forecast = run([
        sub(
          id: 'trial',
          price: 0,
          isFreeTrial: true,
          trialEndDate: DateTime(2026, 7, 25),
          priceAfterTrial: 499,
          firstBillDate: DateTime(2026, 7, 25),
        ),
      ]);
      expect(forecast.upcoming, 499);
      expect(forecast.upcomingCount, 1);
    });

    test('weekly sub contributes each hit, split around today', () {
      // Weekly from July 1: hits 1, 8 (billed) and 15 (today→billed), 22, 29.
      final forecast = run([
        sub(
          id: 'weekly',
          price: 10,
          cycle: BillingCycle.weekly,
          firstBillDate: DateTime(2026, 7, 1),
        ),
      ]);
      // 1, 8, 15 billed = 30; 22, 29 upcoming = 20.
      expect(forecast.billedSoFar, 30);
      expect(forecast.upcoming, 20);
      expect(forecast.upcomingCount, 2);
    });

    test('convertedCharge callback drives the currency math', () {
      final forecast = BudgetForecast.forMonth(
        subscriptions: [
          sub(
            id: 'eur',
            price: 100,
            currency: 'EUR',
            firstBillDate: DateTime(2026, 1, 20),
          ),
        ],
        today: _today,
        convertedCharge: (s) => s.chargePerRenewal * 1.1, // pretend EUR→USD
      );
      expect(forecast.upcoming, closeTo(110, 0.001));
    });

    test('empty portfolio yields a zero forecast', () {
      final forecast = run([]);
      expect(forecast.billedSoFar, 0);
      expect(forecast.upcoming, 0);
      expect(forecast.upcomingCount, 0);
      expect(forecast.projected, 0);
    });

    test('reads today from the injected clock', () {
      final s = [sub(id: 's', price: 100, firstBillDate: DateTime(2026, 1, 20))];
      // On the 10th, the 20th is still upcoming.
      final early = withClock(
        Clock.fixed(DateTime(2026, 7, 10)),
        () => BudgetForecast.forMonth(
          subscriptions: s,
          today: clock.now(),
          convertedCharge: (x) => x.chargePerRenewal,
        ),
      );
      expect(early.upcomingCount, 1);
      // On the 25th, the 20th has already billed.
      final late = withClock(
        Clock.fixed(DateTime(2026, 7, 25)),
        () => BudgetForecast.forMonth(
          subscriptions: s,
          today: clock.now(),
          convertedCharge: (x) => x.chargePerRenewal,
        ),
      );
      expect(late.upcomingCount, 0);
      expect(late.billedSoFar, 100);
    });
  });
}
