import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/subscription.dart';
import '../models/sync_status.dart';
import 'database_service.dart';
import 'sync_queue.dart';

/// Service for syncing Hive data with Firestore
class SyncService {
  factory SyncService() => _instance;
  SyncService._internal();
  static final SyncService _instance = SyncService._internal();

  /// Injectable for tests (fake_cloud_firestore); production always
  /// resolves the default instance. A getter (not a field) so merely
  /// constructing the singleton doesn't demand a live Firebase app.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  FirebaseFirestore get _firestore =>
      debugFirestoreOverride ?? FirebaseFirestore.instance;

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

  /// Track IDs we deleted locally so the remote listener doesn't re-delete
  /// from Hive. Normally an ID is removed when its matching remote `removed`
  /// event arrives; [_markLocallyDeleted] caps the set (evicting oldest) so a
  /// delete that never round-trips (e.g. offline) can't grow it unbounded.
  /// Insertion-ordered (Set literal is a LinkedHashSet), so `first` is oldest.
  final Set<String> _locallyDeletedIds = {};
  static const int _maxLocallyDeletedIds = 500;

  /// Record a locally-initiated delete, evicting the oldest tracked IDs if the
  /// set has grown past [_maxLocallyDeletedIds].
  void _markLocallyDeleted(String subId) {
    _locallyDeletedIds.add(subId);
    while (_locallyDeletedIds.length > _maxLocallyDeletedIds) {
      _locallyDeletedIds.remove(_locallyDeletedIds.first);
    }
  }

  /// Initialize sync for a user
  Future<void> initialize(String uid) async {
    if (_initialized && _currentUid == uid) return;
    _currentUid = uid;
    _initialized = true;

    syncStatus.value = SyncStatus.syncing;

    try {
      // Replay writes queued while offline BEFORE merging: a queued
      // hard-delete must remove the remote doc first, or the merge below
      // would see it as remote-only and resurrect it locally.
      await drainPendingOps(uid);

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
        sub
          ..ownerUid = uid
          ..updatedAt ??= DateTime.now();
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

    final purgeCutoff = DateTime.now().subtract(const Duration(days: 30));

    for (final doc in remoteSnapshot.docs) {
      final remoteData = doc.data();
      final remoteSub = Subscription.fromJson(remoteData);

      // Purge soft-deletes that have aged past the 30-day Recently Deleted
      // window: hard-delete from remote and drop any local copy. This stops
      // long-dead subs from resurrecting onto other devices and keeps the
      // remote collection from accumulating tombstones forever.
      if (remoteSub.deletedAt != null &&
          remoteSub.deletedAt!.isBefore(purgeCutoff)) {
        try {
          await doc.reference.delete();
        } catch (e) {
          debugPrint('Expired soft-delete remote purge failed: $e');
        }
        if (_db.getSubscriptionById(doc.id) != null) {
          await _db.deleteSubscription(doc.id);
        }
        continue;
      }

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

  /// Listen for remote Firestore changes.
  ///
  /// Critical: only tick the [remoteDataChangeTicker] when an actual
  /// local-Hive write happened. Firestore fires multiple snapshot events
  /// for one logical change (cache → server confirm → metadata), and
  /// without filtering, the user's own delete bounces back as 4–5 ticks,
  /// each one cascading into a `loadSubscriptions()` and a home_screen
  /// rebuild. That rebuild storm thrashes any visible snackbar's
  /// animation controller and stalls its auto-dismiss timer.
  void _startRemoteListener(String uid) {
    _syncListener?.cancel();
    _syncListener = _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .snapshots()
        .listen(
      (snapshot) {
        var didWriteHive = false;
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
                  didWriteHive = true;
                }
              }
              break;
            case DocumentChangeType.removed:
              // Skip if we initiated this delete locally (already in
              // recently deleted or hard-deleted) — no Hive write needed.
              if (_locallyDeletedIds.remove(change.doc.id)) {
                break;
              }
              _db.deleteSubscription(change.doc.id);
              didWriteHive = true;
              break;
          }
        }
        if (didWriteHive) {
          remoteDataChangeTicker.value++;
        }
        // A server-confirmed (non-cache) snapshot means Firestore is
        // reachable — replay any writes queued while offline. Runs after
        // the docChanges above so last-write-wins has already reconciled
        // local state with whatever the server just delivered.
        if (!snapshot.metadata.isFromCache) {
          unawaited(drainPendingOps(uid));
        }
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

  /// Push a single subscription to Firestore.
  ///
  /// On failure (usually offline) the push is queued in [SyncQueue] and
  /// replayed by [drainPendingOps] once Firestore is reachable again.
  Future<void> pushSubscription(String uid, Subscription sub) async {
    try {
      await _pushToRemote(uid, sub);
      if (syncStatus.value == SyncStatus.offline) {
        syncStatus.value = SyncStatus.synced;
      }
      // This write got through — flush anything still queued.
      unawaited(drainPendingOps(uid));
    } catch (e) {
      debugPrint('Push subscription error: $e');
      _handleSyncError(e);
      await SyncQueue().enqueuePush(uid, sub.id);
    }
  }

  Future<void> _pushToRemote(String uid, Subscription sub) async {
    sub.ownerUid ??= uid;
    final json = sub.toJson();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .doc(sub.id)
        .set(json, SetOptions(merge: true))
        .timeout(const Duration(seconds: 10));
  }

  /// Delete a subscription from Firestore.
  ///
  /// On failure (usually offline) the delete is queued in [SyncQueue] and
  /// replayed by [drainPendingOps] once Firestore is reachable again.
  Future<void> deleteRemoteSubscription(String uid, String subId) async {
    _markLocallyDeleted(subId);
    try {
      await _deleteFromRemote(uid, subId);
    } catch (e) {
      debugPrint('Delete remote subscription error: $e');
      _handleSyncError(e);
      await SyncQueue().enqueueDelete(uid, subId);
    }
  }

  Future<void> _deleteFromRemote(String uid, String subId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .doc(subId)
        .delete()
        .timeout(const Duration(seconds: 10));
  }

  bool _draining = false;

  /// Replay queued offline writes (oldest first) for [uid].
  ///
  /// Push ops send the sub's *current* local state — if the local copy was
  /// updated (or merged from remote) since the op was queued, the fresher
  /// state is what gets pushed, so a replay can't clobber newer data with
  /// stale data. A push op whose sub no longer exists locally is dropped
  /// (a queued delete op has superseded it or the sub was purged).
  ///
  /// Stops at the first failure — the remaining ops stay queued for the
  /// next drain trigger (startup, force sync, successful push, or the
  /// first server-confirmed snapshot after reconnect).
  Future<void> drainPendingOps(String uid) async {
    final queue = SyncQueue();
    if (_draining || queue.isEmpty) return;
    _draining = true;
    try {
      await queue.purgeStale();
      for (final op in queue.opsForUser(uid)) {
        try {
          if (op.op == SyncQueue.opDelete) {
            // Re-mark: the original mark may have been evicted from the
            // capped set while this op sat in the queue.
            _markLocallyDeleted(op.subId);
            await _deleteFromRemote(uid, op.subId);
          } else {
            final sub = _db.getSubscriptionById(op.subId);
            if (sub != null) {
              await _pushToRemote(uid, sub);
            }
          }
          await queue.remove(op.subId);
        } catch (e) {
          debugPrint('Drain pending op failed (${op.op} ${op.subId}): $e');
          _handleSyncError(e);
          return;
        }
      }
      if (syncStatus.value == SyncStatus.offline) {
        syncStatus.value = SyncStatus.synced;
      }
    } finally {
      _draining = false;
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
      String uid, String householdId,) async {
    await _householdListener?.cancel();

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
          // Exclude the partner's soft-deleted subs (deletedAt set) so they
          // don't linger in household spend views / partner lists.
          final subs = snapshot.docs
              .map((doc) => Subscription.fromJson(doc.data()))
              .where((sub) => sub.deletedAt == null)
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
      await drainPendingOps(uid);
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
