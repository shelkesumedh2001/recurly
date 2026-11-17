import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/household.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/services/split_service.dart';
import 'package:recurly/utils/split_copies.dart';
import 'package:recurly/widgets/split_subscription_sheet.dart';

void main() {
  group('splitShares', () {
    test('one member gets the slider share', () {
      expect(splitShares(['b'], 30), {'b': 30});
    });
    test('several members split equally with the owner', () {
      final s = splitShares(['b', 'c'], 30);
      expect(s.keys, ['b', 'c']);
      expect(s['b'], closeTo(100 / 3, 1e-9));
      expect(splitShares(['b', 'c', 'd'], 30)['d'], 25);
    });
    test('nobody picked: no shares', () {
      expect(splitShares([], 50), isEmpty);
    });
  });

  group('planSplitChange', () {
    test('a new split proposes to everyone', () {
      final p = planSplitChange(null, {'b': 25, 'c': 25});
      expect(p.propose, ['b', 'c']);
      expect(p.removed, isEmpty);
      expect(p.entries.every((e) => e['accepted'] == false), isTrue);
    });

    test('unchanged accepted shares stay accepted; changed ones re-propose',
        () {
      final current = [
        {'uid': 'b', 'sharePercent': 50, 'accepted': true},
        {'uid': 'c', 'sharePercent': 20, 'accepted': true},
      ];
      final p = planSplitChange(current, {'b': 50, 'c': 25});
      expect(p.propose, ['c']);
      expect(p.entries.firstWhere((e) => e['uid'] == 'b')['accepted'], isTrue);
      expect(p.entries.firstWhere((e) => e['uid'] == 'c')['accepted'], isFalse);
    });

    test('a pending (not accepted) share is re-sent', () {
      final current = [
        {'uid': 'b', 'sharePercent': 50, 'accepted': false},
      ];
      expect(planSplitChange(current, {'b': 50}).propose, ['b']);
    });

    test('members left out are removed', () {
      final current = [
        {'uid': 'b', 'sharePercent': 33, 'accepted': true},
        {'uid': 'c', 'sharePercent': 33, 'accepted': true},
      ];
      final p = planSplitChange(current, {'b': 50});
      expect(p.removed, ['c']);
      expect(p.entries.single['uid'], 'b');
    });
  });

  test('memberNames round-trip; older households have none', () {
    final h = Household.fromJson({
      'id': 'h',
      'members': ['a', 'b', 'c'],
      'memberNames': {'a': 'Sam', 'b': 'Alex'},
    });
    expect(h.memberNames, {'a': 'Sam', 'b': 'Alex'});
    expect(Household.fromJson(h.toJson()).memberNames, h.memberNames);
    expect(Household.fromJson({'members': ['a']}).memberNames, isEmpty);
  });

  test('my share with several members, pending or accepted', () {
    final sub = Subscription(
      id: 's',
      name: 'Rent',
      price: 90,
      billingCycle: BillingCycle.monthly,
      firstBillDate: DateTime(2026, 11, 1),
      category: SubscriptionCategory.other,
      createdAt: DateTime(2026, 11, 1),
      ownerUid: 'a',
      splitWith: [
        {'uid': 'b', 'sharePercent': 100 / 3, 'accepted': true},
        {'uid': 'c', 'sharePercent': 100 / 3, 'accepted': false},
      ],
    );
    expect(myShareFraction(sub, 'a'), closeTo(2 / 3, 1e-9));
    expect(myShareFraction(sub, 'a', includePending: true), closeTo(1 / 3, 1e-9));
  });

  group('splitSharesError (unequal shares)', () {
    test('any mix that leaves the owner something is fine', () {
      expect(splitSharesError({'b': 50, 'c': 20}), isNull);
      expect(splitSharesError({'b': 12.5, 'c': 37.5, 'd': 25}), isNull);
    });
    test('members may cover the whole price', () {
      expect(splitSharesError({'b': 60, 'c': 40}), isNull);
    });
    test('over 100% is refused', () {
      expect(splitSharesError({'b': 60, 'c': 50}), contains('110%'));
    });
    test('zero, negative or unreadable shares are refused', () {
      expect(splitSharesError({'b': 0, 'c': 50}), isNotNull);
      expect(splitSharesError({'b': -5, 'c': 50}), isNotNull);
      expect(splitSharesError({'b': double.nan, 'c': 50}), isNotNull);
    });
    test('unequal shares keep acceptance only where unchanged', () {
      final current = [
        {'uid': 'b', 'sharePercent': 50, 'accepted': true},
        {'uid': 'c', 'sharePercent': 25, 'accepted': true},
      ];
      final p = planSplitChange(current, {'b': 50, 'c': 30});
      expect(p.propose, ['c']);
    });
  });
}

