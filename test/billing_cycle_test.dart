import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
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
    test('custom behaves as monthly (no customDays field exists)', () {
      final monthly = addOneCycle(BillingCycle.monthly, DateTime(2025, 1, 31));
      final custom = addOneCycle(BillingCycle.custom, DateTime(2025, 1, 31));
      expect(custom, monthly);
    });
  });
}
