import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';

Subscription _trialSub({required DateTime trialEnd}) {
  return Subscription(
    id: 'test',
    name: 'Test',
    price: 0,
    billingCycle: BillingCycle.monthly,
    firstBillDate: DateTime(2025, 1, 1),
    category: SubscriptionCategory.other,
    createdAt: DateTime(2025, 1, 1),
    isFreeTrial: true,
    trialEndDate: trialEnd,
  );
}

void main() {
  group('isTrialExpiredAt — date-only comparison', () {
    test('trial end is today at 00:00, checked at 14:00 same day → NOT expired', () {
      final today = DateTime(2025, 6, 15);
      final sub = _trialSub(trialEnd: today);
      final now = DateTime(2025, 6, 15, 14, 0);

      expect(sub.isTrialExpiredAt(now), isFalse);
    });

    test('trial end timestamped 09:00 today, checked at 23:59 same day → NOT expired', () {
      final sub = _trialSub(trialEnd: DateTime(2025, 6, 15, 9, 0));
      final now = DateTime(2025, 6, 15, 23, 59);

      expect(sub.isTrialExpiredAt(now), isFalse);
    });

    test('trial end yesterday → expired', () {
      final sub = _trialSub(trialEnd: DateTime(2025, 6, 14));
      final now = DateTime(2025, 6, 15, 0, 1);

      expect(sub.isTrialExpiredAt(now), isTrue);
    });

    test('trial end tomorrow → not expired', () {
      final sub = _trialSub(trialEnd: DateTime(2025, 6, 16));
      final now = DateTime(2025, 6, 15, 23, 59);

      expect(sub.isTrialExpiredAt(now), isFalse);
    });

    test('not a free trial → never expired even with past trial end', () {
      final sub = Subscription(
        id: 'test',
        name: 'Test',
        price: 9.99,
        billingCycle: BillingCycle.monthly,
        firstBillDate: DateTime(2025, 1, 1),
        category: SubscriptionCategory.other,
        createdAt: DateTime(2025, 1, 1),
        trialEndDate: DateTime(2024, 1, 1),
      );

      expect(sub.isTrialExpiredAt(DateTime(2025, 6, 15)), isFalse);
    });

    test('free trial with null trialEndDate → not expired', () {
      final sub = Subscription(
        id: 'test',
        name: 'Test',
        price: 0,
        billingCycle: BillingCycle.monthly,
        firstBillDate: DateTime(2025, 1, 1),
        category: SubscriptionCategory.other,
        createdAt: DateTime(2025, 1, 1),
        isFreeTrial: true,
      );

      expect(sub.isTrialExpiredAt(DateTime(2025, 6, 15)), isFalse);
    });
  });
}
