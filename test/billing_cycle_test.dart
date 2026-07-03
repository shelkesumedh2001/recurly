import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/utils/billing_cycle.dart';

void main() {
  group('addOneCycle — monthly', () {
    test('Jan 31 → Feb 28 (non-leap year, day clamped)', () {
      final result = addOneCycle(BillingCycle.monthly, DateTime(2025, 1, 31));
      expect(result, DateTime(2025, 2, 28));
    });

    test('Jan 31 → Feb 29 (leap year, day clamped)', () {
      final result = addOneCycle(BillingCycle.monthly, DateTime(2024, 1, 31));
      expect(result, DateTime(2024, 2, 29));
    });

    test('Mar 31 → Apr 30 (30-day month, day clamped)', () {
      final result = addOneCycle(BillingCycle.monthly, DateTime(2025, 3, 31));
      expect(result, DateTime(2025, 4, 30));
    });

    test('Dec 31 → Jan 31 (year rollover, no clamp needed)', () {
      final result = addOneCycle(BillingCycle.monthly, DateTime(2025, 12, 31));
      expect(result, DateTime(2026, 1, 31));
    });

    test('Jun 15 → Jul 15 (ordinary case)', () {
      final result = addOneCycle(BillingCycle.monthly, DateTime(2025, 6, 15));
      expect(result, DateTime(2025, 7, 15));
    });

    test('preserves hour/minute on ordinary case', () {
      final result = addOneCycle(
        BillingCycle.monthly,
        DateTime(2025, 6, 15, 9, 30),
      );
      expect(result, DateTime(2025, 7, 15, 9, 30));
    });
  });

  group('addOneCycle — yearly', () {
    test('Feb 29 leap → Feb 28 next (non-leap) year', () {
      final result = addOneCycle(BillingCycle.yearly, DateTime(2024, 2, 29));
      expect(result, DateTime(2025, 2, 28));
    });

    test('Jan 15 2025 → Jan 15 2026', () {
      final result = addOneCycle(BillingCycle.yearly, DateTime(2025, 1, 15));
      expect(result, DateTime(2026, 1, 15));
    });
  });

  group('addOneCycle — weekly', () {
    test('Jan 1 → Jan 8 (calendar day, not 168h)', () {
      final result = addOneCycle(BillingCycle.weekly, DateTime(2025, 1, 1));
      expect(result, DateTime(2025, 1, 8));
    });

    test('Dec 28 → Jan 4 (month + year rollover)', () {
      final result = addOneCycle(BillingCycle.weekly, DateTime(2025, 12, 28));
      expect(result, DateTime(2026, 1, 4));
    });

    test('preserves hour/minute across 7-day add', () {
      final result = addOneCycle(
        BillingCycle.weekly,
        DateTime(2025, 3, 5, 0, 0),
      );
      expect(result.year, 2025);
      expect(result.month, 3);
      expect(result.day, 12);
      expect(result.hour, 0);
      expect(result.minute, 0);
    });
  });

  group('addOneCycle — custom', () {
    test('falls back to 30-day add when customDays is null (legacy)', () {
      final result = addOneCycle(BillingCycle.custom, DateTime(2025, 1, 1));
      expect(result, DateTime(2025, 1, 31));
    });

    test('14-day cycle: Jan 1 → Jan 15', () {
      final result = addOneCycle(
        BillingCycle.custom,
        DateTime(2025, 1, 1),
        customDays: 14,
      );
      expect(result, DateTime(2025, 1, 15));
    });

    test('60-day cycle: Jan 1 → Mar 2 (calendar add, month rollover)', () {
      final result = addOneCycle(
        BillingCycle.custom,
        DateTime(2025, 1, 1),
        customDays: 60,
      );
      expect(result, DateTime(2025, 3, 2));
    });

    test('preserves hour/minute on calendar-day add', () {
      final result = addOneCycle(
        BillingCycle.custom,
        DateTime(2025, 6, 15, 9, 30),
        customDays: 21,
      );
      expect(result, DateTime(2025, 7, 6, 9, 30));
    });

    test('non-positive customDays falls back to 30 (never a zero step)', () {
      // A zero/negative step would make bill-date projection loops hang.
      expect(
        addOneCycle(BillingCycle.custom, DateTime(2025, 1, 1), customDays: 0),
        DateTime(2025, 1, 31),
      );
      expect(
        addOneCycle(BillingCycle.custom, DateTime(2025, 1, 1), customDays: -7),
        DateTime(2025, 1, 31),
      );
    });
  });

  group('Subscription.upcomingRenewals (calendar projection)', () {
    Subscription sub({
      required BillingCycle cycle,
      int? customDays,
      required DateTime firstBillDate,
    }) {
      return Subscription(
        id: 'p1',
        name: 'Proj',
        price: 9.99,
        billingCycle: cycle,
        firstBillDate: firstBillDate,
        category: SubscriptionCategory.entertainment,
        createdAt: DateTime(2026, 1, 1),
        customDays: customDays,
      );
    }

    test('custom 14-day sub projects every 14 days — NOT monthly', () {
      withClock(Clock.fixed(DateTime(2026, 7, 15)), () {
        final s = sub(
          cycle: BillingCycle.custom,
          customDays: 14,
          firstBillDate: DateTime(2026, 7, 6),
        );
        // Next bill: Jul 20 (7/6 + 14), then every 14 days.
        final dates = s.upcomingRenewals(DateTime(2026, 9, 1));
        expect(dates, [
          DateTime(2026, 7, 20),
          DateTime(2026, 8, 3),
          DateTime(2026, 8, 17),
          DateTime(2026, 8, 31),
        ]);
      });
    });

    test('monthly sub projects one date per month with day-clamp', () {
      withClock(Clock.fixed(DateTime(2026, 1, 15)), () {
        final s = sub(
          cycle: BillingCycle.monthly,
          firstBillDate: DateTime(2026, 1, 31),
        );
        // Chained month-adds clamp at February and stay on the 28th —
        // matches nextBillDate's own chaining semantics.
        final dates = s.upcomingRenewals(DateTime(2026, 4, 30));
        expect(dates, [
          DateTime(2026, 1, 31),
          DateTime(2026, 2, 28),
          DateTime(2026, 3, 28),
          DateTime(2026, 4, 28),
        ]);
      });
    });

    test('end date before next bill yields empty projection', () {
      withClock(Clock.fixed(DateTime(2026, 7, 15)), () {
        final s = sub(
          cycle: BillingCycle.monthly,
          firstBillDate: DateTime(2026, 7, 1),
        );
        expect(s.upcomingRenewals(DateTime(2026, 7, 20)), isEmpty);
      });
    });
  });
}
