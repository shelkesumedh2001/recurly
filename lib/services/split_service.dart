import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/split_proposal.dart';
import '../models/subscription.dart';
import 'database_service.dart';

/// Service for managing per-subscription splitting
class SplitService {
  factory SplitService() => _instance;
  SplitService._internal();
  static final SplitService _instance = SplitService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _db = DatabaseService();

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
      totalPrice: sub.price,
      partnerSharePercent: sharePercent,
      currency: sub.currency,
      createdAt: DateTime.now(),
    );

    // Store proposal under partner's split_proposals subcollection
    await _firestore
        .collection('users')
        .doc(partnerUid)
        .collection('split_proposals')
        .doc(subId)
        .set(proposal.toJson());

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
    await _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('subscriptions')
        .doc(subId)
        .set(updatedSub.toJson(), SetOptions(merge: true));
  }

  /// Accept a split proposal
  Future<void> acceptSplit({
    required String partnerUid,
    required SplitProposal proposal,
  }) async {
    // Update proposal as accepted
    await _firestore
        .collection('users')
        .doc(partnerUid)
        .collection('split_proposals')
        .doc(proposal.subId)
        .update({'accepted': true});

    // Update owner's subscription splitWith to mark accepted
    final ownerSubRef = _firestore
        .collection('users')
        .doc(proposal.ownerUid)
        .collection('subscriptions')
        .doc(proposal.subId);

    final ownerSubDoc = await ownerSubRef.get();
    if (ownerSubDoc.exists) {
      final data = ownerSubDoc.data()!;
      final splitWith =
          (data['splitWith'] as List<dynamic>?)?.map((e) {
                final map = Map<String, dynamic>.from(e as Map);
                if (map['uid'] == partnerUid) {
                  map['accepted'] = true;
                }
                return map;
              }).toList() ??
              [];
      // Include updatedAt so owner's remote listener picks up the change
      await ownerSubRef.update({
        'splitWith': splitWith,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    // Create reference subscription in partner's collection
    final ownerSub =
        ownerSubDoc.exists ? Subscription.fromJson(ownerSubDoc.data()!) : null;
    if (ownerSub != null) {
      final partnerSharePrice =
          ownerSub.price * (proposal.partnerSharePercent / 100);

      final referenceSub = ownerSub.copyWith(
        ownerUid: proposal.ownerUid,
        price: partnerSharePrice,
        updatedAt: DateTime.now(),
      );

      // Save to partner's Firestore subscriptions
      await _firestore
          .collection('users')
          .doc(partnerUid)
          .collection('subscriptions')
          .doc(proposal.subId)
          .set(referenceSub.toJson());

      // Also save reference sub to local Hive so it appears in partner's UI immediately
      // (partner may not have Pro sync listener running)
      await _db.addSubscription(referenceSub);
    }

    // Also update local Hive if we're the owner
    final localSub = _db.getSubscriptionById(proposal.subId);
    if (localSub != null && localSub.ownerUid == proposal.ownerUid) {
      final updatedSplitWith = localSub.splitWith?.map((e) {
            if (e['uid'] == partnerUid) {
              return {...e, 'accepted': true};
            }
            return e;
          }).toList() ??
          [];
      await _db.updateSubscription(
        localSub.copyWith(splitWith: updatedSplitWith),
      );
    }
  }

  /// Reject a split proposal
  Future<void> rejectSplit({
    required String partnerUid,
    required SplitProposal proposal,
  }) async {
    // Delete proposal
    await _firestore
        .collection('users')
        .doc(partnerUid)
        .collection('split_proposals')
        .doc(proposal.subId)
        .delete();

    // Remove splitWith from owner's subscription
    final ownerSubRef = _firestore
        .collection('users')
        .doc(proposal.ownerUid)
        .collection('subscriptions')
        .doc(proposal.subId);

    final ownerSubDoc = await ownerSubRef.get();
    if (ownerSubDoc.exists) {
      final data = ownerSubDoc.data()!;
      final splitWith = (data['splitWith'] as List<dynamic>?)
              ?.where((e) => (e as Map)['uid'] != partnerUid)
              .toList() ??
          [];
      await ownerSubRef.update({
        'splitWith': splitWith.isEmpty ? FieldValue.delete() : splitWith,
      });
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

    final ownerSubDoc = await ownerSubRef.get();
    if (ownerSubDoc.exists) {
      final data = ownerSubDoc.data()!;
      final splitWith = (data['splitWith'] as List<dynamic>?)
              ?.where((e) => (e as Map)['uid'] != partnerUid)
              .toList() ??
          [];
      await ownerSubRef.update({
        'splitWith': splitWith.isEmpty ? FieldValue.delete() : splitWith,
      });
    }

    // Delete partner's reference subscription
    await _firestore
        .collection('users')
        .doc(partnerUid)
        .collection('subscriptions')
        .doc(subId)
        .delete();

    // Delete proposal
    await _firestore
        .collection('users')
        .doc(partnerUid)
        .collection('split_proposals')
        .doc(subId)
        .delete();

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
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('split_proposals')
        .where('accepted', isEqualTo: false)
        .get();

    return snapshot.docs.map((doc) {
      return SplitProposal.fromJson(doc.data());
    }).toList();
  }
}
