import 'package:clock/clock.dart';

import '../models/subscription.dart';

/// Partner's "copy" of a split subscription.
///
/// When B accepts A's split, B's collection holds a copy of A's sub billed
/// at B's share. A owns the real doc; B's device derives the copy from it
/// (B already listens to A's household-visible subs) so every owner edit —
/// price, bill date, cycle, trial, archive, delete, restore, share change —
/// reaches the copy without the owner writing into B's data (BUG-6).

/// The accepted share (0..1) that [ownerSub] gives to [myUid], or null.
double? acceptedShareFor(Subscription ownerSub, String myUid) {
  for (final entry in ownerSub.splitWith ?? const <Map<String, dynamic>>[]) {
    if (entry['uid'] == myUid && entry['accepted'] == true) {
      final pct = entry['sharePercent'];
      if (pct is num && pct > 0) return pct.toDouble() / 100;
    }
  }
  return null;
}

/// Fraction (0..1) of [sub]'s cost that [myUid] pays: 1 for my copy of a
/// partner's split sub (already priced at my share — any `splitWith` it
/// carries from older versions is ignored, BUG-3), 1 minus the accepted
/// partner shares for my own subs. The single rule for "what I pay".
double myShareFraction(Subscription sub, String? myUid) {
  final isCopy =
      sub.ownerUid != null && myUid != null && sub.ownerUid != myUid;
  if (isCopy) return 1;
  var mine = 1.0;
  for (final entry in sub.splitWith ?? const <Map<String, dynamic>>[]) {
    final pct = entry['sharePercent'];
    if (entry['accepted'] == true && pct is num) mine -= pct / 100;
  }
  return mine.clamp(0.0, 1.0);
}

/// Who pays what across the household, per month: every household sub
/// counted once at full price from its owner's doc ([monthly] converts it
/// to the display currency), then divided by the accepted shares. My
/// copies of the partner's subs are skipped — their own doc stands for
/// them, so nothing is counted twice or dropped (BUG-5).
({double mine, double partner}) householdSplitTotals({
  required List<Subscription> ownSubs,
  required List<Subscription> partnerSubs,
  required String? myUid,
  required double Function(Subscription sub) monthly,
}) {
  double mine = 0;
  double partner = 0;
  for (final sub in ownSubs) {
    if (sub.ownerUid != null && sub.ownerUid != myUid) continue;
    if (sub.isArchived || sub.deletedAt != null) continue;
    final full = monthly(sub);
    final f = myShareFraction(sub, myUid);
    mine += full * f;
    partner += full * (1 - f);
  }
  for (final sub in partnerSubs) {
    // Their copies of my subs — already counted above.
    if (myUid != null && sub.ownerUid == myUid) continue;
    if (sub.isArchived || sub.deletedAt != null) continue;
    final full = monthly(sub);
    final f = myUid == null ? 0.0 : (acceptedShareFor(sub, myUid) ?? 0);
    mine += full * f;
    partner += full * (1 - f);
  }
  return (mine: mine, partner: partner);
}

/// What [myUid]'s copy of [ownerSub] should look like, or null when there
/// is no accepted split for [myUid] (or the owner deleted the sub).
///
/// The copy carries no `splitWith`: it's already priced at my share, and a
/// copied `splitWith` made every share calculation apply the split a
/// second time (BUG-3, BUG-4). Card links are the owner's, local-only.
Subscription? partnerCopyFor(
  Subscription ownerSub, {
  required String ownerUid,
  required String myUid,
}) {
  if (ownerSub.deletedAt != null) return null;
  final share = acceptedShareFor(ownerSub, myUid);
  if (share == null) return null;

  return Subscription(
    id: ownerSub.id,
    name: ownerSub.name,
    price: ownerSub.price * share,
    currency: ownerSub.currency,
    billingCycle: ownerSub.billingCycle,
    firstBillDate: ownerSub.firstBillDate,
    category: ownerSub.category,
    logoUrl: ownerSub.logoUrl,
    color: ownerSub.color,
    notes: ownerSub.notes,
    isArchived: ownerSub.isArchived,
    createdAt: ownerSub.createdAt,
    isFreeTrial: ownerSub.isFreeTrial,
    trialEndDate: ownerSub.trialEndDate,
    priceAfterTrial:
        ownerSub.priceAfterTrial == null ? null : ownerSub.priceAfterTrial! * share,
    ownerUid: ownerUid,
    householdVisible: ownerSub.householdVisible,
    priceHistory: ownerSub.priceHistory
        ?.map((e) => {
              ...e,
              if (e['price'] is num) 'price': (e['price'] as num) * share,
            },)
        .toList(),
    customDays: ownerSub.customDays,
    updatedAt: clock.now(),
  );
}

/// Whether two copies differ in anything but `updatedAt`.
bool copyDiffers(Subscription a, Subscription b) {
  final ja = a.toJson()..remove('updatedAt');
  final jb = b.toJson()..remove('updatedAt');
  return !_deepEquals(ja, jb);
}

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return (a - b).abs() < 1e-9;
  return a == b;
}

/// Writes that bring local split data in line with the household.
class SplitSyncPlan {
  SplitSyncPlan({
    required this.upsertCopies,
    required this.deleteCopyIds,
    required this.updateOwn,
  });

  /// Copies to create or overwrite (already stamped with `updatedAt`).
  final List<Subscription> upsertCopies;

  /// Copies to remove (owner deleted it, split stopped/declined, owner left).
  final List<String> deleteCopyIds;

  /// My own subs whose `splitWith` names someone who is no longer my
  /// partner (they left, or the household was disbanded) — BUG-9/BUG-10.
  final List<Subscription> updateOwn;

  bool get isEmpty =>
      upsertCopies.isEmpty && deleteCopyIds.isEmpty && updateOwn.isEmpty;
}

/// Plan the sync for [myUid] given my [local] subs (Hive, all of them).
///
/// [partnerUid] null = I have no partner right now (not in a household, or
/// alone in one): every copy goes and every split on my subs is cleared.
/// Otherwise [partnerDocs] must be the partner's household-visible subs
/// from a server-confirmed snapshot (never a cache-only one — an empty
/// cache would read as "the owner deleted everything").
SplitSyncPlan planSplitSync({
  required String myUid,
  required String? partnerUid,
  required List<Subscription> local,
  List<Subscription> partnerDocs = const [],
}) {
  final upserts = <Subscription>[];
  final deletes = <String>[];
  final own = <Subscription>[];

  final desired = <String, Subscription>{};
  if (partnerUid != null) {
    for (final doc in partnerDocs) {
      // The partner's collection also holds THEIR copies of MY subs.
      if ((doc.ownerUid ?? partnerUid) != partnerUid) continue;
      final copy = partnerCopyFor(doc, ownerUid: partnerUid, myUid: myUid);
      if (copy != null) desired[doc.id] = copy;
    }
  }

  final localIds = <String>{};
  for (final sub in local) {
    localIds.add(sub.id);
    final isCopy = sub.ownerUid != null && sub.ownerUid != myUid;
    if (isCopy) {
      final want = sub.ownerUid == partnerUid ? desired[sub.id] : null;
      if (want == null) {
        deletes.add(sub.id);
      } else if (sub.deletedAt != null || copyDiffers(sub, want)) {
        upserts.add(want);
      }
      continue;
    }

    final splits = sub.splitWith;
    if (splits == null || splits.isEmpty) continue;
    final kept = splits.where((e) => e['uid'] == partnerUid).toList();
    if (kept.length != splits.length) {
      own.add(
        kept.isEmpty
            ? sub.copyWith(clearSplitWith: true, updatedAt: clock.now())
            : sub.copyWith(splitWith: kept, updatedAt: clock.now()),
      );
    }
  }

  for (final entry in desired.entries) {
    if (!localIds.contains(entry.key)) upserts.add(entry.value);
  }

  return SplitSyncPlan(
    upsertCopies: upserts,
    deleteCopyIds: deletes,
    updateOwn: own,
  );
}

/// Local subs that belong to a different account than [uid] — left on the
/// device by an earlier sign-in (sign-out keeps local data). They must go
/// before [uid]'s first merge: the merge would upload them into [uid]'s
/// account, and the split sync would take them for copies and delete
/// same-id docs from [uid]'s cloud (P3-4). Safe to drop: that account's own
/// subs are in its cloud, partner copies are re-derived, and [uid]'s own
/// subs come back from the merge. Never-synced subs (no owner) stay.
List<String> foreignSubIds(List<Subscription> local, String uid) => [
      for (final sub in local)
        if (sub.ownerUid != null && sub.ownerUid != uid) sub.id,
    ];

/// Which uid a backup's subs belong to: the header's `ownerUid` (written
/// since 1.0.5) or, for older files, the most common owner among its subs.
String? backupOwnerOf(Map<String, dynamic> data, List<Subscription> subs) {
  final header = data['ownerUid'];
  if (header is String && header.isNotEmpty) return header;
  final counts = <String, int>{};
  for (final s in subs) {
    final o = s.ownerUid;
    if (o != null) counts[o] = (counts[o] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .first
      .key;
}

/// What a restore may write (P3-5). A backup holds its owner's subs AND
/// their copies of a partner's split subs; restoring those copies by id
/// overwrote the partner's real sub and silently ended the split.
///
/// - Subs owned by someone other than [backupOwner] (partner copies) are
///   skipped — copies are always re-derived from the owner's live doc.
/// - The rest become [myUid]'s (null when signed out: local-only data).
/// - Restoring into a different account than the backup's drops their
///   splits: those were with the other account's household partner.
/// - A sub whose id this device already holds as someone else's (my copy
///   of a partner's split sub) is left alone, not replaced by a re-owned
///   full-price duplicate. [existingOwnerOf] gives the local doc's owner.
({List<Subscription> write, int skipped}) planRestore(
  List<Subscription> subs, {
  required String? backupOwner,
  required String? myUid,
  String? Function(String id)? existingOwnerOf,
}) {
  final write = <Subscription>[];
  var skipped = 0;
  final otherAccount =
      backupOwner != null && myUid != null && backupOwner != myUid;
  for (final sub in subs) {
    final owner = sub.ownerUid;
    if (owner != null && backupOwner != null && owner != backupOwner) {
      skipped++;
      continue;
    }
    final existingOwner = existingOwnerOf?.call(sub.id);
    if (existingOwner != null && existingOwner != (myUid ?? owner)) {
      skipped++;
      continue;
    }
    var restored = sub;
    if (myUid != null) restored = restored.copyWith(ownerUid: myUid);
    if (otherAccount) restored = restored.copyWith(clearSplitWith: true);
    write.add(restored);
  }
  return (write: write, skipped: skipped);
}
