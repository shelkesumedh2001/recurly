import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/split_proposal.dart';
import '../models/subscription.dart';
import '../utils/split_copies.dart';
import 'database_service.dart';

/// Service for managing per-subscription splitting
class SplitService {
  factory SplitService() => _instance;
  SplitService._internal();
  static final SplitService _instance = SplitService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _db = DatabaseService();

  /// Every remote op is capped so a flaky connection surfaces as an error
  /// instead of a spinner that hangs forever (same policy as SyncService).
  static const Duration _opTimeout = Duration(seconds: 10);

  Future<T> _timed<T>(Future<T> future) => future.timeout(_opTimeout);

  /// The proposal sent to the partner for [sub]. A running trial is split
  /// at what it will charge, not its $0 trial price; once the trial has
  /// ended the two are the same.
  static SplitProposal buildProposal(
    Subscription sub, {
    required String ownerUid,
    required String partnerUid,
    required double sharePercent,
    required DateTime now,
  }) =>
      SplitProposal(
        subId: sub.id,
        ownerUid: ownerUid,
        partnerUid: partnerUid,
        subscriptionName: sub.name,
        totalPrice: sub.chargePerRenewal,
        afterTrial: sub.isFreeTrial && !sub.isTrialExpiredAt(now),
        partnerSharePercent: sharePercent,
        currency: sub.currency,
        createdAt: now,
      );

  /// Propose (or change) how [subId] is split: [shares] maps each member
  /// to their share in percent; the owner pays the rest.
  ///
  /// Members whose share is unchanged and already accepted keep their
  /// acceptance; everyone else gets a fresh proposal. Members dropped from
  /// the split lose their proposal and copy. A split sub is always visible
  /// to the household — members must be able to read it to follow it.
  Future<void> proposeSplit({
    required String ownerUid,
    required String subId,
    required Map<String, double> shares,
  }) async {
    final sub = _db.getSubscriptionById(subId);
    if (sub == null) throw Exception('Subscription not found');
    final plan = planSplitChange(sub.splitWith, shares);
    final now = DateTime.now();

    // Owner's doc first: the proposal is useless if the member can't read
    // the (now visible) sub when accepting.
    final updatedSub = sub.copyWith(
      splitWith: plan.entries,
      householdVisible: true,
      updatedAt: now,
    );
    await _db.updateSubscription(updatedSub);
    await _timed(_firestore
        .collection('users')
        .doc(ownerUid)
        .collection('subscriptions')
        .doc(subId)
        .set(updatedSub.toJson(), SetOptions(merge: true)),);

    for (final partnerUid in plan.propose) {
      final proposal = buildProposal(
        sub,
        ownerUid: ownerUid,
        partnerUid: partnerUid,
        sharePercent: shares[partnerUid]!,
        now: now,
      );
      await _timed(_firestore
          .collection('users')
          .doc(partnerUid)
          .collection('split_proposals')
          .doc(subId)
          .set(proposal.toJson()),);
    }
    for (final partnerUid in plan.removed) {
      await _dropMember(partnerUid, subId);
    }
  }

  /// A member's copy and proposal of [subId] (household members may delete
  /// both). Their device would also drop the copy on its own once the
  /// owner's doc no longer names them.
  Future<void> _dropMember(String partnerUid, String subId) async {
    final user = _firestore.collection('users').doc(partnerUid);
    await _timed(user.collection('subscriptions').doc(subId).delete());
    await _timed(user.collection('split_proposals').doc(subId).delete());
  }

  /// Accept a split proposal
  Future<void> acceptSplit({
    required String partnerUid,
    required SplitProposal proposal,
  }) async {
    // Update proposal as accepted
    await _timed(_firestore
        .collection('users')
        .doc(partnerUid)
        .collection('split_proposals')
        .doc(proposal.subId)
        .update({'accepted': true}),);

    // Update owner's subscription splitWith to mark accepted
    final ownerSubRef = _firestore
        .collection('users')
        .doc(proposal.ownerUid)
        .collection('subscriptions')
        .doc(proposal.subId);

    final ownerSubDoc = await _timed(ownerSubRef.get());
    if (!ownerSubDoc.exists) return;
    final data = ownerSubDoc.data()!;
    final splitWith = (data['splitWith'] as List<dynamic>?)?.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          if (map['uid'] == partnerUid) map['accepted'] = true;
          return map;
        }).toList() ??
        [];
    // Include updatedAt so owner's remote listener picks up the change
    await _timed(ownerSubRef.update({
      'splitWith': splitWith,
      'updatedAt': DateTime.now().toIso8601String(),
    }),);

    // Create my copy of the owner's sub at my share — the same derivation
    // the household listener uses to keep it in sync (split_copies.dart).
    final referenceSub = partnerCopyFor(
      Subscription.fromJson({...data, 'splitWith': splitWith}),
      ownerUid: proposal.ownerUid,
      myUid: partnerUid,
    );
    if (referenceSub != null) {
      await _timed(_firestore
          .collection('users')
          .doc(partnerUid)
          .collection('subscriptions')
          .doc(proposal.subId)
          .set(referenceSub.toJson()),);

      // Local copy so it shows up right away.
      await _db.addSubscription(referenceSub);
    }
    // (No local "owner" update here: this runs on the acceptor's device,
    // where the only local doc with this id is the copy above. Flipping
    // its splitWith is what double-applied the share.)
  }

  /// Reject a split proposal
  Future<void> rejectSplit({
    required String partnerUid,
    required SplitProposal proposal,
  }) async {
    // Delete proposal
    await _timed(_firestore
        .collection('users')
        .doc(partnerUid)
        .collection('split_proposals')
        .doc(proposal.subId)
        .delete(),);

    // Remove splitWith from owner's subscription
    final ownerSubRef = _firestore
        .collection('users')
        .doc(proposal.ownerUid)
        .collection('subscriptions')
        .doc(proposal.subId);

    final ownerSubDoc = await _timed(ownerSubRef.get());
    if (ownerSubDoc.exists) {
      final data = ownerSubDoc.data()!;
      final splitWith = (data['splitWith'] as List<dynamic>?)
              ?.where((e) => (e as Map)['uid'] != partnerUid)
              .toList() ??
          [];
      // updatedAt: the owner's listener is last-write-wins on it; without
      // the bump the decline never reaches the owner's device.
      await _timed(ownerSubRef.update({
        'splitWith': splitWith.isEmpty ? FieldValue.delete() : splitWith,
        'updatedAt': DateTime.now().toIso8601String(),
      }),);
    }
  }

  /// Stop splitting [subId] with everyone.
  Future<void> removeSplit({
    required String ownerUid,
    required String subId,
  }) async {
    final ownerSubRef = _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('subscriptions')
        .doc(subId);
    final local = _db.getSubscriptionById(subId);
    final members = <String>{
      for (final e in local?.splitWith ?? const <Map<String, dynamic>>[])
        if (e['uid'] is String) e['uid'] as String,
    };

    final ownerSubDoc = await _timed(ownerSubRef.get());
    if (ownerSubDoc.exists) {
      for (final e in (ownerSubDoc.data()!['splitWith'] as List<dynamic>?) ??
          const []) {
        final uid = (e as Map)['uid'];
        if (uid is String) members.add(uid);
      }
      await _timed(ownerSubRef.update({
        'splitWith': FieldValue.delete(),
        'updatedAt': DateTime.now().toIso8601String(),
      }),);
    }

    for (final uid in members) {
      await _dropMember(uid, subId);
    }

    if (local != null) {
      await _db.updateSubscription(
        local.copyWith(clearSplitWith: true, updatedAt: DateTime.now()),
      );
    }
  }

  /// Listen to incoming split proposals for a user
  Stream<List<SplitProposal>> listenToSplitProposals(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('split_proposals')
        .where('accepted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return SplitProposal.fromJson(doc.data());
      }).toList();
    });
  }

  /// Get all pending split proposals
  Future<List<SplitProposal>> getPendingProposals(String uid) async {
    final snapshot = await _timed(_firestore
        .collection('users')
        .doc(uid)
        .collection('split_proposals')
        .where('accepted', isEqualTo: false)
        .get(),);

    return snapshot.docs.map((doc) {
      return SplitProposal.fromJson(doc.data());
    }).toList();
  }
}

/// How a split changes when the owner picks new [shares] (member uid →
/// percent) for a sub whose split is [current].
({List<Map<String, dynamic>> entries, List<String> propose, List<String> removed})
    planSplitChange(
  List<Map<String, dynamic>>? current,
  Map<String, double> shares,
) {
  final before = {
    for (final e in current ?? const <Map<String, dynamic>>[])
      if (e['uid'] is String) e['uid'] as String: e,
  };
  final entries = <Map<String, dynamic>>[];
  final propose = <String>[];
  for (final MapEntry(key: uid, value: pct) in shares.entries) {
    final old = before[uid];
    final oldPct = old?['sharePercent'];
    final keep = old != null &&
        old['accepted'] == true &&
        oldPct is num &&
        (oldPct - pct).abs() < 1e-9;
    entries.add({'uid': uid, 'sharePercent': pct, 'accepted': keep});
    if (!keep) propose.add(uid);
  }
  return (
    entries: entries,
    propose: propose,
    removed: [
      for (final uid in before.keys)
        if (!shares.containsKey(uid)) uid,
    ],
  );
}
