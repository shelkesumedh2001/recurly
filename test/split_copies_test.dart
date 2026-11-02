import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/utils/split_copies.dart';

/// Group B (splits/household) — numbers are the hand-calculated ones from
/// the 2026-11-02 test pass (REPORT.md H2–H10).
const a = 'uidA';
const b = 'uidB';

Subscription _sub(
  String id,
  double price, {
  String owner = a,
  List<Map<String, dynamic>>? splitWith,
  BillingCycle cycle = BillingCycle.monthly,
  bool archived = false,
  DateTime? deletedAt,
}) {
  return Subscription(
    id: id,
    name: id,
    price: price,
    billingCycle: cycle,
    firstBillDate: DateTime(2026, 10, 5),
    category: SubscriptionCategory.entertainment,
    createdAt: DateTime(2026, 11, 2),
    ownerUid: owner,
    splitWith: splitWith,
    isArchived: archived,
    deletedAt: deletedAt,
  );
}

List<Map<String, dynamic>> _split(String uid, num pct, {bool accepted = true}) =>
    [
      {'uid': uid, 'sharePercent': pct, 'accepted': accepted},
    ];

void main() {
  // A owns Netflix 15.49 (50% → B), Spotify 11.99 (30% → B), iCloud 120/y,
  // Gym 40. B owns YouTube 22.99 (30% → A), Disney+ 9.99 (50% → A).
  final netflix = _sub('netflix', 15.49, splitWith: _split(b, 50));
  final spotify = _sub('spotify', 11.99, splitWith: _split(b, 30));
  final icloud = _sub('icloud', 120, cycle: BillingCycle.yearly);
  final gym = _sub('gym', 40);
  final youtube = _sub('youtube', 22.99, owner: b, splitWith: _split(a, 30));
  final disney = _sub('disney', 9.99, owner: b, splitWith: _split(a, 50));

  final aOwn = [netflix, spotify, icloud, gym];
  final bOwn = [youtube, disney];

  List<Subscription> copiesFor(String me, String partner, List<Subscription> docs) =>
      [
        for (final d in docs)
          if (partnerCopyFor(d, ownerUid: partner, myUid: me) case final c?) c,
      ];

  double myShare(List<Subscription> subs, String uid) => subs.fold(
        0,
        (sum, s) => sum + s.monthlyEquivalent * myShareFraction(s, uid),
      );

  group('partnerCopyFor', () {
    test('priced at my share, no splitWith, no card (BUG-3/BUG-4)', () {
      final copy = partnerCopyFor(netflix, ownerUid: a, myUid: b)!;
      expect(copy.price, closeTo(7.745, 1e-9));
      expect(copy.splitWith, isNull);
      expect(copy.ownerUid, a);
      expect(copy.cardId, isNull);
    });

    test('none while pending, declined, or for someone else', () {
      final pending = _sub('p', 10, splitWith: _split(b, 50, accepted: false));
      expect(partnerCopyFor(pending, ownerUid: a, myUid: b), isNull);
      expect(partnerCopyFor(gym, ownerUid: a, myUid: b), isNull);
      expect(partnerCopyFor(netflix, ownerUid: a, myUid: 'uidC'), isNull);
    });

    test('follows owner edits: price, date, archive (BUG-6)', () {
      final edited = netflix.copyWith(
        price: 17.99,
        firstBillDate: DateTime(2026, 10, 7),
        isArchived: true,
      );
      final copy = partnerCopyFor(edited, ownerUid: a, myUid: b)!;
      expect(copy.price, closeTo(8.995, 1e-9));
      expect(copy.firstBillDate, DateTime(2026, 10, 7));
      expect(copy.isArchived, isTrue);
    });

    test('owner deleted it → no copy', () {
      final deleted = netflix.copyWith(deletedAt: DateTime(2026, 11, 2));
      expect(partnerCopyFor(deleted, ownerUid: a, myUid: b), isNull);
    });

    test('trial and price history are scaled too', () {
      final trial = netflix.copyWith(
        isFreeTrial: true,
        trialEndDate: DateTime(2026, 11, 20),
        priceAfterTrial: 20,
        priceHistory: [
          {'price': 10, 'currency': 'USD', 'date': '2026-09-01T00:00:00.000'},
        ],
      );
      final copy = partnerCopyFor(trial, ownerUid: a, myUid: b)!;
      expect(copy.priceAfterTrial, 10);
      expect(copy.priceHistory!.single['price'], 5);
    });
  });

  group('My share (H4b: A 78.03, B 32.43)', () {
    test('both sides match the hand calculation', () {
      final aLocal = [...aOwn, ...copiesFor(a, b, bOwn)];
      final bLocal = [...bOwn, ...copiesFor(b, a, aOwn)];
      expect(myShare(aLocal, a), closeTo(78.03, 0.005));
      expect(myShare(bLocal, b), closeTo(32.43, 0.005));
    });

    test('a legacy copy carrying the owner splitWith is not halved twice '
        '(BUG-3)', () {
      final legacy = partnerCopyFor(netflix, ownerUid: a, myUid: b)!
          .copyWith(splitWith: _split(b, 50));
      expect(myShareFraction(legacy, b), 1);
    });
  });

  group('householdSplitTotals (BUG-5)', () {
    double monthly(Subscription s) => s.monthlyEquivalent;

    test('A and B cards agree with Home My share and sum to the total', () {
      final aCard = householdSplitTotals(
        ownSubs: [...aOwn, ...copiesFor(a, b, bOwn)],
        partnerSubs: [...bOwn, ...copiesFor(b, a, aOwn)],
        myUid: a,
        monthly: monthly,
      );
      final bCard = householdSplitTotals(
        ownSubs: [...bOwn, ...copiesFor(b, a, aOwn)],
        partnerSubs: [...aOwn, ...copiesFor(a, b, bOwn)],
        myUid: b,
        monthly: monthly,
      );
      expect(aCard.mine, closeTo(78.03, 0.005));
      expect(aCard.partner, closeTo(32.43, 0.005));
      expect(bCard.mine, closeTo(32.43, 0.005));
      expect(bCard.partner, closeTo(78.03, 0.005));
      expect(aCard.mine + aCard.partner, closeTo(110.46, 0.005));
    });
  });

  group('planSplitSync', () {
    test('creates a missing copy and fixes a stale one (BUG-6)', () {
      final stale = partnerCopyFor(netflix, ownerUid: a, myUid: b)!;
      final raised = netflix.copyWith(price: 17.99);
      final plan = planSplitSync(
        myUid: b,
        partnerUid: a,
        local: [...bOwn, stale],
        partnerDocs: [raised, spotify, icloud, gym],
      );
      final byId = {for (final c in plan.upsertCopies) c.id: c};
      expect(byId.keys, unorderedEquals(['netflix', 'spotify']));
      expect(byId['netflix']!.price, closeTo(8.995, 1e-9));
      expect(plan.deleteCopyIds, isEmpty);
      expect(plan.updateOwn, isEmpty);
    });

    test('nothing to do when copies are current', () {
      final plan = planSplitSync(
        myUid: b,
        partnerUid: a,
        local: [...bOwn, ...copiesFor(b, a, aOwn)],
        partnerDocs: [...aOwn, ...copiesFor(a, b, bOwn)],
      );
      expect(plan.isEmpty, isTrue);
    });

    test('owner deleted or stopped the split → copy removed (BUG-6/BUG-7)',
        () {
      final plan = planSplitSync(
        myUid: b,
        partnerUid: a,
        local: [...bOwn, ...copiesFor(b, a, aOwn)],
        // Spotify deleted (absent), Netflix split removed.
        partnerDocs: [netflix.copyWith(clearSplitWith: true), icloud, gym],
      );
      expect(plan.deleteCopyIds, unorderedEquals(['netflix', 'spotify']));
    });

    test("partner's copies of MY subs in their collection are ignored", () {
      final plan = planSplitSync(
        myUid: a,
        partnerUid: b,
        local: [...aOwn, ...copiesFor(a, b, bOwn)],
        partnerDocs: [...bOwn, ...copiesFor(b, a, aOwn)],
      );
      expect(plan.isEmpty, isTrue);
    });

    test('no partner: every copy goes, every split is cleared (BUG-9/10)',
        () {
      final archivedSplit = _sub('times', 13.40,
          splitWith: _split(b, 50), archived: true,);
      final plan = planSplitSync(
        myUid: a,
        partnerUid: null,
        local: [...aOwn, archivedSplit, ...copiesFor(a, b, bOwn)],
      );
      expect(plan.deleteCopyIds, unorderedEquals(['youtube', 'disney']));
      expect(plan.updateOwn.map((s) => s.id),
          unorderedEquals(['netflix', 'spotify', 'times']),);
      expect(plan.updateOwn.every((s) => s.splitWith == null), isTrue);
      expect(plan.upsertCopies, isEmpty);
    });

    test('new partner: splits and copies from the old one go (BUG-10)', () {
      final plan = planSplitSync(
        myUid: a,
        partnerUid: 'uidC',
        local: [...aOwn, ...copiesFor(a, b, bOwn)],
      );
      expect(plan.deleteCopyIds, unorderedEquals(['youtube', 'disney']));
      expect(plan.updateOwn.map((s) => s.id),
          unorderedEquals(['netflix', 'spotify']),);
    });

    test('a pending proposal to the current partner is kept', () {
      final pending = _sub('p', 10, splitWith: _split(b, 50, accepted: false));
      final plan = planSplitSync(
        myUid: a,
        partnerUid: b,
        local: [pending],
        partnerDocs: const [],
      );
      expect(plan.isEmpty, isTrue);
    });
  });

  group('foreignSubIds (P3-4)', () {
    test("another account's subs and its partner copies go; mine and "
        'never-synced ones stay', () {
      final local = [
        _sub('c-own', 10, owner: 'uidC'),
        _sub('c-copy', 5, owner: 'uidD'),
        _sub('mine', 7, owner: b),
        Subscription(
          id: 'local-only',
          name: 'local',
          price: 3,
          billingCycle: BillingCycle.monthly,
          firstBillDate: DateTime(2026, 10, 5),
          category: SubscriptionCategory.other,
          createdAt: DateTime(2026, 11, 2),
        ),
      ];
      expect(foreignSubIds(local, b), unorderedEquals(['c-own', 'c-copy']));
    });
  });
}
