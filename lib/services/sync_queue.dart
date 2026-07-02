import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../utils/constants.dart';

/// A single queued sync write that hasn't reached Firestore yet.
class PendingSyncOp {
  PendingSyncOp({
    required this.subId,
    required this.uid,
    required this.op,
    required this.queuedAt,
  });

  final String subId;
  final String uid;

  /// [SyncQueue.opPush] or [SyncQueue.opDelete].
  final String op;
  final DateTime queuedAt;
}

/// Persistent queue of sync writes that failed to reach Firestore —
/// typically because the device was offline (fixes the known gap where
/// offline deletes only reached remote at the next full merge).
///
/// Ops are keyed by subscription id so they coalesce: only the latest op
/// per sub survives, which matches last-write-wins sync semantics (a
/// "delete forever" queued after a soft-delete push replaces it, etc.).
/// Push ops don't store a payload — the current local sub is read from
/// Hive at drain time, so a replayed push can never resurrect stale data.
///
/// Each op is tagged with the uid it was queued under; [opsForUser] only
/// returns ops for the signed-in user, so an account switch can't replay
/// one user's writes into another user's collection.
class SyncQueue {
  /// Binds to the box opened by DatabaseService.initialize().
  factory SyncQueue() =>
      _instance ??= SyncQueue.withBox(Hive.box<dynamic>(AppConstants.syncQueueBox));

  /// Direct construction for tests (with an optional fake clock).
  SyncQueue.withBox(this._box, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static SyncQueue? _instance;

  /// Test-only: replace (or clear) the singleton the `SyncQueue()` factory
  /// hands out, so services under test use a temp-dir box.
  @visibleForTesting
  // ignore: use_setters_to_change_properties
  static void debugSetInstance(SyncQueue? instance) {
    _instance = instance;
  }

  final Box<dynamic> _box;
  final DateTime Function() _clock;

  static const String opPush = 'push';
  static const String opDelete = 'delete';

  /// Hard cap on queued ops; oldest are evicted first (same rationale as
  /// SyncService's `_locallyDeletedIds` cap — a device that stays offline
  /// forever must not grow storage unbounded).
  static const int maxOps = 500;

  /// Ops older than this are dropped by [purgeStale] — they refer to local
  /// state that has since aged past the Recently Deleted window anyway.
  static const Duration staleAfter = Duration(days: 30);

  bool get isEmpty => _box.isEmpty;

  int get length => _box.length;

  /// Queue a push of the sub's current local state.
  Future<void> enqueuePush(String uid, String subId) =>
      _enqueue(uid, subId, opPush);

  /// Queue a remote hard-delete.
  Future<void> enqueueDelete(String uid, String subId) =>
      _enqueue(uid, subId, opDelete);

  Future<void> _enqueue(String uid, String subId, String op) async {
    await _box.put(subId, {
      'uid': uid,
      'op': op,
      'queuedAt': _clock().toIso8601String(),
    });
    while (_box.length > maxOps) {
      final oldest = _allOps().first;
      await _box.delete(oldest.subId);
    }
  }

  /// Pending ops for [uid], oldest first.
  List<PendingSyncOp> opsForUser(String uid) =>
      _allOps().where((op) => op.uid == uid).toList();

  /// Remove an op after it has been successfully replayed (or superseded).
  Future<void> remove(String subId) => _box.delete(subId);

  /// Drop ops older than [staleAfter], regardless of uid.
  Future<void> purgeStale() async {
    final cutoff = _clock().subtract(staleAfter);
    final staleIds = _allOps()
        .where((op) => op.queuedAt.isBefore(cutoff))
        .map((op) => op.subId)
        .toList();
    for (final id in staleIds) {
      await _box.delete(id);
    }
  }

  List<PendingSyncOp> _allOps() {
    final ops = <PendingSyncOp>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is! Map) continue;
      ops.add(
        PendingSyncOp(
          subId: key as String,
          uid: raw['uid'] as String? ?? '',
          op: raw['op'] as String? ?? opPush,
          queuedAt:
              DateTime.tryParse(raw['queuedAt'] as String? ?? '') ?? _clock(),
        ),
      );
    }
    ops.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return ops;
  }
}
