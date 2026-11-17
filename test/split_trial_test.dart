import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/split_proposal.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/services/split_service.dart';

void main() {
  final now = DateTime(2026, 11, 17, 10);

  Subscription trial({DateTime? ends, double? after = 15.49}) => Subscription(
        id: 't',
        name: 'Netflix',
        price: 0,
        billingCycle: BillingCycle.monthly,
        firstBillDate: DateTime(2026, 11, 10),
        category: SubscriptionCategory.entertainment,
        createdAt: DateTime(2026, 11, 10),
        isFreeTrial: true,
        trialEndDate: ends ?? DateTime(2026, 11, 24),
        priceAfterTrial: after,
      );

  SplitProposal propose(Subscription sub) => SplitService.buildProposal(
        sub,
        ownerUid: 'a',
        partnerUid: 'b',
        sharePercent: 50,
        now: now,
      );

  test('a running trial is split at its post-trial price, flagged', () {
    final p = propose(trial());
    expect(p.totalPrice, 15.49);
    expect(p.partnerShareAmount, closeTo(7.745, 1e-9));
    expect(p.afterTrial, isTrue);
  });

  test('an ended trial is split at the same price, not flagged', () {
    final p = propose(trial(ends: DateTime(2026, 11, 1)));
    expect(p.totalPrice, 15.49);
    expect(p.afterTrial, isFalse);
  });

  test('a normal sub: its price, not flagged', () {
    final sub = trial().copyWith(isFreeTrial: false, price: 9.99);
    final p = propose(sub);
    expect(p.totalPrice, 9.99);
    expect(p.afterTrial, isFalse);
  });

  test('afterTrial survives JSON and defaults to false for old proposals', () {
    final p = propose(trial());
    expect(SplitProposal.fromJson(p.toJson()).afterTrial, isTrue);
    expect(
      SplitProposal.fromJson(p.toJson()..remove('afterTrial')).afterTrial,
      isFalse,
    );
  });
}
