import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/household.dart';
import '../utils/constants.dart';

/// Service for managing household creation, invites, and membership
class HouseholdService {
  factory HouseholdService() => _instance;
  HouseholdService._internal();
  static final HouseholdService _instance = HouseholdService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new household
  Future<Household> createHousehold(String uid, String name) async {
    final inviteCode = generateInviteCode();
    final householdId = _firestore.collection('households').doc().id;

    final household = Household(
      id: householdId,
      name: name,
      createdBy: uid,
      members: [uid],
      inviteCode: inviteCode,
      inviteExpiry: DateTime.now().add(
        Duration(hours: AppConstants.inviteCodeExpiryHours),
      ),
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('households')
        .doc(householdId)
        .set(household.toJson());

    // Store invite code for lookup
    await _firestore.collection('invites').doc(inviteCode).set({
      'householdId': householdId,
      'createdBy': uid,
      'expiry': household.inviteExpiry!.toIso8601String(),
    });

    // Update user's householdId
    await _firestore.collection('users').doc(uid).update({
      'householdId': householdId,
    });

    return household;
  }

  /// Generate a 6-character invite code
  String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      AppConstants.inviteCodeLength,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Join a household with an invite code
  Future<Household> joinHousehold(String uid, String code) async {
    final codeUpper = code.toUpperCase().trim();

    // Look up invite code
    final inviteDoc =
        await _firestore.collection('invites').doc(codeUpper).get();
    if (!inviteDoc.exists) {
      throw Exception('Invalid invite code');
    }

    final inviteData = inviteDoc.data()!;
    final expiry = DateTime.parse(inviteData['expiry'] as String);
    if (DateTime.now().isAfter(expiry)) {
      throw Exception('Invite code has expired');
    }

    final householdId = inviteData['householdId'] as String;

    // Get household
    final householdDoc =
        await _firestore.collection('households').doc(householdId).get();
    if (!householdDoc.exists) {
      throw Exception('Household not found');
    }

    final household = Household.fromJson(
        {...householdDoc.data()!, 'id': householdId});

    // Check max members
    if (household.members.length >= AppConstants.householdMaxMembers) {
      throw Exception('Household is full');
    }

    // Check not already a member
    if (household.members.contains(uid)) {
      throw Exception('You are already in this household');
    }

    // Add member
    final updatedMembers = [...household.members, uid];
    await _firestore.collection('households').doc(householdId).update({
      'members': updatedMembers,
    });

    // Update user's householdId
    await _firestore.collection('users').doc(uid).update({
      'householdId': householdId,
    });

    return household.copyWith(members: updatedMembers);
  }

  /// Leave a household (for non-creator members)
  Future<void> leaveHousehold(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final householdId = userDoc.data()?['householdId'] as String?;
    if (householdId == null) return;

    final householdDoc =
        await _firestore.collection('households').doc(householdId).get();
    if (!householdDoc.exists) return;

    final members = (householdDoc.data()?['members'] as List<dynamic>?)
            ?.cast<String>() ??
        [];

    // Clean up only the caller's own split data
    // Partner's device will self-cleanup via householdCleanupProvider
    await cleanupOwnSplitData(uid);

    members.remove(uid);

    await _firestore.collection('households').doc(householdId).update({
      'members': members,
    });

    await _firestore.collection('users').doc(uid).update({
      'householdId': FieldValue.delete(),
    });
  }

  /// Disband household (creator only)
  Future<void> disbandHousehold(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final householdId = userDoc.data()?['householdId'] as String?;
    if (householdId == null) return;

    final householdDoc =
        await _firestore.collection('households').doc(householdId).get();
    if (!householdDoc.exists) return;

    final data = householdDoc.data()!;
    if (data['createdBy'] != uid) {
      throw Exception('Only the creator can disband the household');
    }

    final members =
        (data['members'] as List<dynamic>?)?.cast<String>() ?? [];

    // Clean up only the caller's own split data (we can read our own collections)
    // Partner's device will self-cleanup via householdCleanupProvider
    await cleanupOwnSplitData(uid);

    // Clear householdId for OTHER members first (so isHouseholdMember check passes)
    for (final memberId in members) {
      if (memberId != uid) {
        await _firestore.collection('users').doc(memberId).update({
          'householdId': FieldValue.delete(),
        });
      }
    }

    // Clear creator's own householdId last
    await _firestore.collection('users').doc(uid).update({
      'householdId': FieldValue.delete(),
    });

    // Delete invite code
    final inviteCode = data['inviteCode'] as String?;
    if (inviteCode != null) {
      await _firestore.collection('invites').doc(inviteCode).delete();
    }

    // Delete household
    await _firestore.collection('households').doc(householdId).delete();
  }

  /// Clean up the caller's own split data (Firestore only).
  /// Each user can only read/list their own collections, so we only clean our own.
  /// The partner's device self-cleans via householdCleanupProvider.
  Future<void> cleanupOwnSplitData(String uid) async {
    try {
      // 1. Delete all split_proposals
      final proposals = await _firestore
          .collection('users')
          .doc(uid)
          .collection('split_proposals')
          .get();
      for (final doc in proposals.docs) {
        await doc.reference.delete();
      }

      // 2. Delete reference subscriptions (subs owned by someone else)
      // 3. Clear splitWith on own subscriptions
      final subs = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscriptions')
          .get();
      for (final doc in subs.docs) {
        final data = doc.data();
        final ownerUid = data['ownerUid'] as String?;
        if (ownerUid != null && ownerUid != uid) {
          // Reference sub from a split — delete it
          await doc.reference.delete();
        } else {
          // Own subscription — clear splitWith if present
          final splitWith = data['splitWith'] as List<dynamic>?;
          if (splitWith != null && splitWith.isNotEmpty) {
            await doc.reference.update({'splitWith': FieldValue.delete()});
          }
        }
      }
    } catch (e) {
      debugPrint('cleanupOwnSplitData error: $e');
    }
  }

  /// Refresh invite code
  Future<String> refreshInviteCode(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final householdId = userDoc.data()?['householdId'] as String?;
    if (householdId == null) throw Exception('Not in a household');

    final householdDoc =
        await _firestore.collection('households').doc(householdId).get();
    if (!householdDoc.exists) throw Exception('Household not found');
    if (householdDoc.data()?['createdBy'] != uid) {
      throw Exception('Only the creator can refresh the invite code');
    }

    // Delete old invite
    final oldCode = householdDoc.data()?['inviteCode'] as String?;
    if (oldCode != null) {
      await _firestore.collection('invites').doc(oldCode).delete();
    }

    // Generate new code
    final newCode = generateInviteCode();
    final newExpiry = DateTime.now().add(
      Duration(hours: AppConstants.inviteCodeExpiryHours),
    );

    await _firestore.collection('households').doc(householdId).update({
      'inviteCode': newCode,
      'inviteExpiry': newExpiry.toIso8601String(),
    });

    await _firestore.collection('invites').doc(newCode).set({
      'householdId': householdId,
      'createdBy': uid,
      'expiry': newExpiry.toIso8601String(),
    });

    return newCode;
  }

  /// Stream household data
  Stream<Household?> listenToHousehold(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Household.fromJson({...doc.data()!, 'id': doc.id});
    });
  }

  /// Get household by ID
  Future<Household?> getHousehold(String householdId) async {
    final doc =
        await _firestore.collection('households').doc(householdId).get();
    if (!doc.exists) return null;
    return Household.fromJson({...doc.data()!, 'id': doc.id});
  }
}
