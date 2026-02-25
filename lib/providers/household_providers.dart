import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/household.dart';
import '../services/database_service.dart';
import '../services/household_service.dart';
import '../services/sync_service.dart';
import 'auth_providers.dart';
import 'subscription_providers.dart';

/// Provider for the household service singleton
final householdServiceProvider = Provider<HouseholdService>((ref) {
  return HouseholdService();
});

/// Stream provider for the current household
final currentHouseholdProvider = StreamProvider<Household?>((ref) {
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile == null || profile.householdId == null) {
    return Stream.value(null);
  }
  final householdService = ref.watch(householdServiceProvider);
  return householdService.listenToHousehold(profile.householdId!);
});

/// Provider for household members list
final householdMembersProvider = Provider<List<String>>((ref) {
  final household = ref.watch(currentHouseholdProvider).value;
  return household?.members ?? [];
});

/// Provider for whether user is in a household
final isInHouseholdProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).value;
  return profile?.householdId != null;
});

/// Provider for whether user is the household creator
final isHouseholdCreatorProvider = Provider<bool>((ref) {
  final household = ref.watch(currentHouseholdProvider).value;
  final user = ref.watch(currentFirebaseUserProvider);
  if (household == null || user == null) return false;
  return household.createdBy == user.uid;
});

/// Self-cleanup: if profile still has householdId but the household doc is gone,
/// clean up stale householdId, split data, and local references.
final householdCleanupProvider = Provider<void>((ref) {
  final profile = ref.watch(currentUserProfileProvider).value;
  final user = ref.watch(currentFirebaseUserProvider);
  final household = ref.watch(currentHouseholdProvider);

  if (user == null || profile == null || profile.householdId == null) return;

  // Profile has a householdId, but the household stream resolved to null (deleted)
  household.whenData((h) {
    if (h == null && profile.householdId != null) {
      debugPrint('Household cleanup: clearing stale householdId and split data');
      final uid = user.uid;

      // 1. Clear householdId from Firestore profile
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'householdId': FieldValue.delete()});

      // 2. Clean up own Firestore split data (proposals, reference subs, splitWith)
      HouseholdService().cleanupOwnSplitData(uid);

      // 3. Clean up local Hive split data
      final db = DatabaseService();
      final localSubs = db.getActiveSubscriptions();
      for (final sub in localSubs) {
        if (sub.ownerUid != null && sub.ownerUid != uid) {
          // Reference sub from a split — delete it entirely
          db.deleteSubscription(sub.id);
        } else if (sub.splitWith != null && sub.splitWith!.isNotEmpty) {
          // Own sub with split — clear splitWith
          db.updateSubscription(
            sub.copyWith(clearSplitWith: true, updatedAt: DateTime.now()),
          );
        }
      }

      // 4. Stop household sync listener
      SyncService().disposeHouseholdSync();

      // 5. Reload subscriptions to reflect changes
      ref.read(subscriptionProvider.notifier).loadSubscriptions();
    }
  });
});
