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

  /// Propose a split to a partner
  Future<void> proposeSplit({
    required String ownerUid,
    required String subId,
    required String partnerUid,
    required double sharePercent,
  }) async {
    final sub = _db.getSubscriptionById(subId);
    if (sub == null) throw Exception('Subscription not found');

    final proposal = SplitProposal(
      subId: subId,
      ownerUid: ownerUid,
      partnerUid: partnerUid,
      subscriptionName: sub.name,
      totalPrice: sub.currentPrice,
      partnerSharePercent: sharePercent,
      currency: sub.currency,
      createdAt: DateTime.now(),
    );

    // Store proposal under partner's split_proposals subcollection
    await _timed(_firestore
        .collection('users')
        .doc(partnerUid)
        .collection('split_proposals')
        .doc(subId)
        .set(proposal.toJson()),);

    // Update the subscription's splitWith field
    final splitEntry = {
      'uid': partnerUid,
      'sharePercent': sharePercent,
      'accepted': false,
    };

    final updatedSub = sub.copyWith(
      splitWith: [splitEntry],
      updatedAt: DateTime.now(),
    );
    await _db.updateSubscription(updatedSub);

    // Push to owner's Firestore
    await _timed(_firestore
        .collection('users')
        .doc(ownerUid)
        .collection('subscriptions')
        .doc(subId)
        .set(updatedSub.toJson(), SetOptions(merge: true)),);
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
    // its splitWith is what double-applied the share — BUG-3.)
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
      // the bump the decline never reaches the owner's device (BUG-8).
      await _timed(ownerSubRef.update({
        'splitWith': splitWith.isEmpty ? FieldValue.delete() : splitWith,
        'updatedAt': DateTime.now().toIso8601String(),
      }),);
    }
  }

  /// Remove a split from a subscription
  Future<void> removeSplit({
    required String ownerUid,
    required String subId,
    required String partnerUid,
  }) async {
    // Remove from owner's subscription
    final ownerSubRef = _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('subscriptions')
        .doc(subId);

    final ownerSubDoc = await _timed(ownerSubRef.get());
    if (ownerSubDoc.exists) {
      final data = ownerSubDoc.data()!;
      final splitWith = (data['splitWith'] as List<dynamic>?)
              ?.where((e) => (e as Map)['uid'] != partnerUid)
              .toList() ??
          [];
      await _timed(ownerSubRef.update({
        'splitWith': splitWith.isEmpty ? FieldValue.delete() : splitWith,
        'updatedAt': DateTime.now().toIso8601String(),
      }),);
    }

    // Delete partner's reference subscription
    await _timed(_firestore
        .collection('users')
        .doc(partnerUid)
        .collection('subscriptions')
        .doc(subId)
        .delete(),);

    // Delete proposal
    await _timed(_firestore
        .collection('users')
        .doc(partnerUid)
        .collection('split_proposals')
        .doc(subId)
        .delete(),);

    // Update local Hive
    final localSub = _db.getSubscriptionById(subId);
    if (localSub != null) {
      await _db.updateSubscription(
        localSub.copyWith(clearSplitWith: true, updatedAt: DateTime.now()),
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
