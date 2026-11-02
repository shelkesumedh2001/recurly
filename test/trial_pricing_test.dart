import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/app_preferences.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/services/notification_service.dart';

/// BUG-24 / BUG-15 / BUG-20: what a trial costs before and after it ends.
/// Numbers are the ones from the 2026-11-02 test pass (account C).
Subscription _trial({
  required String name,
  required double price,
  required double after,
  required DateTime end,
  BillingCycle cycle = BillingCycle.monthly,
  int? customDays,
}) {
  return Subscription(
    id: name,
    name: name,
    price: price,
    billingCycle: cycle,
    customDays: customDays,
    firstBillDate: end,
    category: SubscriptionCategory.productivity,
    createdAt: DateTime(2026, 11, 2),
    isFreeTrial: true,
    trialEndDate: end,
    priceAfterTrial: after,
  );
}

T _on<T>(DateTime day, T Function() body) =>
    withClock(Clock.fixed(day), body);

void main() {
  final canva =
      _trial(name: 'Canva Pro', price: 15, after: 12.99, end: DateTime(2026, 11, 9));
  final duolingo =
      _trial(name: 'Duolingo', price: 0, after: 9.99, end: DateTime(2026, 11, 16));

  group('currentPrice / monthlyEquivalent (BUG-24)', () {
    test('during the trial the trial price counts', () {
      _on(DateTime(2026, 11, 8, 12), () {
        expect(canva.currentPrice, 15);
        expect(canva.monthlyEquivalent, 15);
        expect(duolingo.monthlyEquivalent, 0);
      });
    });

    test('the trial-end day itself still counts as trial', () {
      _on(DateTime(2026, 11, 9, 20), () {
        expect(canva.monthlyEquivalent, 15);
      });
    });

    test('after the trial ends the post-trial price counts', () {
      _on(DateTime(2026, 11, 10), () {
        expect(canva.currentPrice, 12.99);
        expect(canva.monthlyEquivalent, 12.99);
        expect(canva.formattedPrice, r'$12.99');
      });
      _on(DateTime(2026, 11, 17), () {
        expect(duolingo.monthlyEquivalent, 9.99);
        expect(duolingo.formattedPrice, r'$9.99');
      });
    });

    test('expired trial with no post-trial price keeps its price', () {
      final sub = Subscription(
        id: 'x',
        name: 'x',
        price: 5,
        billingCycle: BillingCycle.monthly,
        firstBillDate: DateTime(2026, 11, 1),
        category: SubscriptionCategory.other,
        createdAt: DateTime(2026, 11, 1),
        isFreeTrial: true,
        trialEndDate: DateTime(2026, 11, 1),
      );
      _on(DateTime(2026, 11, 20), () => expect(sub.monthlyEquivalent, 5));
    });

    test('custom cycle uses the post-trial price per bill', () {
      final sub = _trial(
        name: 'c',
        price: 0,
        after: 30,
        end: DateTime(2026, 11, 1),
        cycle: BillingCycle.custom,
        customDays: 14,
      );
      _on(DateTime(2026, 11, 20), () {
        expect(sub.monthlyEquivalent, closeTo(30 * 30.44 / 14, 1e-9));
      });
    });

    test('monthlyEquivalentOf ignores the trial state', () {
      _on(DateTime(2026, 11, 20), () {
        expect(canva.monthlyEquivalentOf(2), 2);
      });
    });
  });

  group('upcoming charges use chargePerRenewal (BUG-15)', () {
    test('trial-end bill is the post-trial price', () {
      _on(DateTime(2026, 11, 2), () {
        expect(duolingo.nextBillDate, DateTime(2026, 11, 16));
        expect(duolingo.chargePerRenewal, 9.99);
        expect(canva.chargePerRenewal, 12.99);
      });
    });
  });

  group('convertedFromTrial (D1 "Still subscribed")', () {
    test('becomes a normal sub on the same billing chain', () {
      _on(DateTime(2026, 11, 17), () {
        final before = duolingo.nextBillDate;
        final paid = duolingo.convertedFromTrial();
        expect(paid.isFreeTrial, isFalse);
        expect(paid.trialEndDate, isNull);
        expect(paid.priceAfterTrial, isNull);
        expect(paid.price, 9.99);
        expect(paid.monthlyEquivalent, 9.99);
        expect(paid.nextBillDate, before);
        expect(paid.nextBillDate, DateTime(2026, 12, 16));
      });
    });

    test('a non-trial is returned unchanged', () {
      _on(DateTime(2026, 11, 17), () {
        final paid = duolingo.convertedFromTrial();
        expect(identical(paid.convertedFromTrial(), paid), isTrue);
      });
    });
  });

  group('renewal reminder skips the trial-end bill (BUG-20)', () {
    test('skipped when a trial reminder covers it', () {
      expect(
        NotificationService.isCoveredByTrialReminder(
          duolingo,
          AppPreferences(),
          DateTime(2026, 11, 16),
        ),
        isTrue,
      );
    });

    test('later bills still get the renewal reminder', () {
      expect(
        NotificationService.isCoveredByTrialReminder(
          duolingo,
          AppPreferences(),
          DateTime(2026, 12, 16),
        ),
        isFalse,
      );
    });

    test('not skipped when every trial reminder is off', () {
      expect(
        NotificationService.isCoveredByTrialReminder(
          duolingo,
          AppPreferences(trialReminder1DayEnabled: false),
          DateTime(2026, 11, 16),
        ),
        isFalse,
      );
    });
  });
}
