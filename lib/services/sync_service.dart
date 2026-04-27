import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/subscription.dart';
import '../models/sync_status.dart';
import 'database_service.dart';

/// Service for syncing Hive data with Firestore
class SyncService {
  factory SyncService() => _instance;
  SyncService._internal();
  static final SyncService _instance = SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _db = DatabaseService();

  StreamSubscription<QuerySnapshot>? _syncListener;
  StreamSubscription<QuerySnapshot>? _householdListener;

  final ValueNotifier<SyncStatus> syncStatus =
      ValueNotifier(SyncStatus.idle);

  /// Partner subscriptions (in-memory, not persisted to Hive)
  final ValueNotifier<List<Subscription>> partnerSubscriptions =
      ValueNotifier([]);

  String? _currentUid;
  bool _initialized = false;

  /// Track IDs we deleted locally so the remote listener doesn't re-delete from Hive
  final Set<String> _locallyDeletedIds = {};

  /// Initialize sync for a user
  Future<void> initialize(String uid) async {
    if (_initialized && _currentUid == uid) return;
    _currentUid = uid;
    _initialized = true;

    syncStatus.value = SyncStatus.syncing;

    try {
      // Check if this is a first-time migration
      await _handleFirstSignIn(uid);

      // Start listening for remote changes
      _startRemoteListener(uid);

      // Backfill householdVisible on existing docs
      await _backfillHouseholdVisible(uid);

      syncStatus.value = SyncStatus.synced;
    } catch (e) {
      debugPrint('Sync initialization error: $e');
      syncStatus.value = SyncStatus.error;
    }
  }

  /// Handle first sign-in data migration
  Future<void> _handleFirstSignIn(String uid) async {
    final remoteSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .limit(1)
        .get();

    final localSubs = _db.getActiveSubscriptions();

    if (remoteSnapshot.docs.isEmpty && localSubs.isNotEmpty) {
      // Upload all local subs to Firestore
      await uploadLocalData(uid);
    } else if (remoteSnapshot.docs.isNotEmpty) {
      // Merge: fetch all remote, compare by updatedAt
      await _mergeRemoteData(uid);
    }
  }

  /// Upload all local Hive data to Firestore
  Future<void> uploadLocalData(String uid) async {
    syncStatus.value = SyncStatus.syncing;
    try {
      final subs = _db.getAllSubscriptions();
      final batch = _firestore.batch();
      final collection = _firestore
          .collection('users')
          .doc(uid)
          .collection('subscriptions');

      for (final sub in subs) {
        sub.ownerUid = uid;
        sub.updatedAt ??= DateTime.now();
        final json = sub.toJson();
        batch.set(collection.doc(sub.id), json);
        // Also update local with ownerUid
        await _db.updateSubscription(sub);
      }

      await batch.commit();
      syncStatus.value = SyncStatus.synced;
      debugPrint('Uploaded ${subs.length} subscriptions to Firestore');
    } catch (e) {
      debugPrint('Upload error: $e');
      syncStatus.value = SyncStatus.error;
    }
  }

  /// Merge remote data with local (last-write-wins on updatedAt)
  Future<void> _mergeRemoteData(String uid) async {
    final remoteSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .get();

    for (final doc in remoteSnapshot.docs) {
      final remoteData = doc.data();
      final remoteSub = Subscription.fromJson(remoteData);
      final localSub = _db.getSubscriptionById(doc.id);

      if (localSub == null) {
        // Remote-only: save locally
        await _db.addSubscription(remoteSub);
      } else {
        // Both exist: keep the newer one
        final remoteUpdated = remoteSub.updatedAt ?? remoteSub.createdAt;
        final localUpdated = localSub.updatedAt ?? localSub.createdAt;

        if (remoteUpdated.isAfter(localUpdated)) {
          await _db.updateSubscription(remoteSub);
        } else if (localUpdated.isAfter(remoteUpdated)) {
          // Push local to remote
          await pushSubscription(uid, localSub);
        }
      }
    }

    // Upload any local-only subs that don't exist remotely
    final remoteIds = remoteSnapshot.docs.map((d) => d.id).toSet();
    final localSubs = _db.getAllSubscriptions();
    for (final sub in localSubs) {
      if (!remoteIds.contains(sub.id)) {
        sub.ownerUid = uid;
        await pushSubscription(uid, sub);
      }
    }
  }

  /// Listen for remote Firestore changes
  void _startRemoteListener(String uid) {
    _syncListener?.cancel();
    _syncListener = _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          switch (change.type) {
            case DocumentChangeType.added:
            case DocumentChangeType.modified:
              final data = change.doc.data();
              if (data != null) {
                final remoteSub = Subscription.fromJson(data);
                final localSub = _db.getSubscriptionById(change.doc.id);
                final remoteUpdated =
                    remoteSub.updatedAt ?? remoteSub.createdAt;
                final localUpdated =
                    localSub?.updatedAt ?? localSub?.createdAt;

                if (localSub == null ||
                    localUpdated == null ||
                    remoteUpdated.isAfter(localUpdated)) {
                  _db.addSubscription(remoteSub);
                }
              }
              break;
            case DocumentChangeType.removed:
              // Skip if we initiated this delete locally (already in recently deleted or hard-deleted)
              if (_locallyDeletedIds.remove(change.doc.id)) {
                break;
              }
              _db.deleteSubscription(change.doc.id);
              break;
          }
        }
        // Notify all listeners that data has changed. Using a ValueNotifier<int>
        // instead of a single VoidCallback so multiple subscribers can coexist
        // without the last one overwriting earlier ones.
        remoteDataChangeTicker.value++;
      },
      onError: (e) {
        debugPrint('Sync listener error: $e');
        _handleSyncError(e);
      },
    );
  }

  /// Ticker that increments whenever the remote listener processes a change.
  /// Subscribe via `addListener` to react to remote-driven updates. Supports
  /// any number of concurrent subscribers (replaces the prior single-callback
  /// field that silently overwrote earlier listeners on re-assignment).
  final ValueNotifier<int> remoteDataChangeTicker = ValueNotifier(0);

  /// Push a single subscription to Firestore
  Future<void> pushSubscription(String uid, Subscription sub) async {
    try {
      sub.ownerUid ??= uid;
      final json = sub.toJson();
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscriptions')
          .doc(sub.id)
          .set(json, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      if (syncStatus.value == SyncStatus.offline) {
        syncStatus.value = SyncStatus.synced;
      }
    } catch (e) {
      debugPrint('Push subscription error: $e');
      _handleSyncError(e);
    }
  }

  /// Delete a subscription from Firestore
  Future<void> deleteRemoteSubscription(String uid, String subId) async {
    _locallyDeletedIds.add(subId);
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscriptions')
          .doc(subId)
          .delete()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Delete remote subscription error: $e');
      _handleSyncError(e);
    }
  }

  /// Determine if error is a connectivity issue and update status accordingly
  void _handleSyncError(Object e) {
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('unavailable') ||
        errorStr.contains('unable to resolve') ||
        errorStr.contains('timeout') ||
        errorStr.contains('network')) {
      syncStatus.value = SyncStatus.offline;
    } else {
      syncStatus.value = SyncStatus.error;
    }
  }

  /// Initialize household sync — listen to partner's visible subscriptions
  Future<void> initializeHouseholdSync(
      String uid, String householdId) async {
    _householdListener?.cancel();

    try {
      // Get household to find partner uid
      final householdDoc =
          await _firestore.collection('households').doc(householdId).get();
      if (!householdDoc.exists) return;

      final members = (householdDoc.data()?['members'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final partnerUid = members.firstWhere(
        (m) => m != uid,
        orElse: () => '',
      );
      if (partnerUid.isEmpty) return;

      // Query must match Firestore rules: only householdVisible == true docs are readable
      _householdListener = _firestore
          .collection('users')
          .doc(partnerUid)
          .collection('subscriptions')
          .where('householdVisible', isEqualTo: true)
          .snapshots()
          .listen(
        (snapshot) {
          final subs = snapshot.docs
              .map((doc) => Subscription.fromJson(doc.data()))
              .toList();
          partnerSubscriptions.value = subs;
        },
        onError: (e) {
          debugPrint('Household sync error: $e');
        },
      );
    } catch (e) {
      debugPrint('Household sync init error: $e');
    }
  }

  /// Dispose household sync — cancel listener and clear partner subs
  void disposeHouseholdSync() {
    _householdListener?.cancel();
    _householdListener = null;
    partnerSubscriptions.value = [];
  }

  /// Backfill householdVisible on existing Firestore docs that may lack the field
  Future<void> _backfillHouseholdVisible(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscriptions')
          .get();

      final batch = _firestore.batch();
      var count = 0;
      for (final doc in snapshot.docs) {
        if (!doc.data().containsKey('householdVisible')) {
          batch.update(doc.reference, {'householdVisible': true});
          count++;
        }
      }
      if (count > 0) {
        await batch.commit();
        debugPrint('Backfilled householdVisible on $count docs');
      }
    } catch (e) {
      debugPrint('Backfill householdVisible error: $e');
    }
  }

  /// Force re-sync
  Future<void> forceSync(String uid) async {
    syncStatus.value = SyncStatus.syncing;
    try {
      await _mergeRemoteData(uid);
      syncStatus.value = SyncStatus.synced;
    } catch (e) {
      debugPrint('Force sync error: $e');
      syncStatus.value = SyncStatus.error;
    }
  }

  /// Dispose listeners on sign-out. Safe to call repeatedly — all operations
  /// are idempotent.
  void dispose() {
    _syncListener?.cancel();
    _householdListener?.cancel();
    _syncListener = null;
    _householdListener = null;
    _initialized = false;
    _currentUid = null;
    syncStatus.value = SyncStatus.idle;
    partnerSubscriptions.value = [];
    // Per-session state — clear so a later sign-in under a different uid
    // doesn't see IDs that were deleted by the previous user.
    _locallyDeletedIds.clear();
  }
}
