import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/custom_category.dart';
import 'custom_category_service.dart';

/// What a category sync must do to bring this device and the account's
/// `users/{uid}/categories` collection in line.
class CategorySyncPlan {
  CategorySyncPlan({
    required this.putLocal,
    required this.deleteLocal,
    required this.upload,
  });

  /// Remote versions to store on this device.
  final List<CustomCategory> putLocal;

  /// Local ids to remove (deleted on another device, or another account's).
  final List<String> deleteLocal;

  /// Local categories the account doesn't have yet, or has an older copy of.
  final List<CustomCategory> upload;

  bool get isEmpty => putLocal.isEmpty && deleteLocal.isEmpty && upload.isEmpty;
}

/// A remote category doc: the category, or a tombstone left by a delete
/// (so a device that was offline doesn't upload it back).
({CustomCategory? category, String id, bool deleted, DateTime changedAt})
    parseCategoryDoc(String id, Map<String, dynamic> data) {
  final changedAt = DateTime.tryParse(data['updatedAt'] as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
  if (data['deleted'] == true) {
    return (category: null, id: id, deleted: true, changedAt: changedAt);
  }
  try {
    final c = CustomCategory.fromJson({...data, 'id': id});
    return (category: c, id: id, deleted: false, changedAt: c.changedAt);
  } catch (_) {
    // Malformed doc: treat as absent rather than break the whole sync.
    return (category: null, id: id, deleted: false, changedAt: changedAt);
  }
}

/// Newest change wins, per category. Pure; see [CategorySync.syncAll].
///
/// [remote] null means "only these docs changed" (listener deltas): local
/// categories missing from it are left alone instead of uploaded.
CategorySyncPlan planCategorySync({
  required String uid,
  required List<CustomCategory> local,
  required Map<String, Map<String, dynamic>> remote,
  bool remoteIsComplete = true,
}) {
  final putLocal = <CustomCategory>[];
  final deleteLocal = <String>[];
  final upload = <CustomCategory>[];

  final localById = <String, CustomCategory>{};
  for (final c in local) {
    if (c.ownerUid != null && c.ownerUid != uid) {
      deleteLocal.add(c.id); // another account's (P3-4 rule)
    } else {
      localById[c.id] = c;
    }
  }

  for (final entry in remote.entries) {
    final doc = parseCategoryDoc(entry.key, entry.value);
    final mine = localById.remove(entry.key);
    if (doc.deleted) {
      if (mine == null) continue;
      if (mine.changedAt.isAfter(doc.changedAt)) {
        upload.add(mine); // edited here after the delete elsewhere
      } else {
        deleteLocal.add(entry.key);
      }
      continue;
    }
    final theirs = doc.category;
    if (theirs == null) {
      if (mine != null) upload.add(mine);
      continue;
    }
    if (mine == null || theirs.changedAt.isAfter(mine.changedAt)) {
      putLocal.add(theirs..ownerUid = uid);
    } else if (mine.changedAt.isAfter(theirs.changedAt) ||
        mine.ownerUid == null) {
      upload.add(mine);
    }
  }

  if (remoteIsComplete) {
    // Never synced to this account (made offline / before 1.0.6 / restored
    // from a backup): give it to the account.
    upload.addAll(localById.values);
  }

  return CategorySyncPlan(
    putLocal: putLocal,
    deleteLocal: deleteLocal,
    upload: upload,
  );
}

/// Keeps custom categories in sync across the account's devices through
/// `users/{uid}/categories`. Writes rely on Firestore's own offline queue
/// (categories are small, last-write-wins, never hard-deleted remotely).
class CategorySync {
  /// The Firestore instance is resolved on use, so constructing this (e.g. to listen
  /// to [changed]) never needs a live Firebase app.
  CategorySync(this._firestoreOf, this._service);

  final FirebaseFirestore Function() _firestoreOf;
  final CustomCategoryService _service;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listener;

  /// Bumped after sync changed this device's categories.
  final ValueNotifier<int> changed = ValueNotifier(0);

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestoreOf().collection('users').doc(uid).collection('categories');

  /// Full merge at sign-in, then listen for other devices' changes.
  Future<void> start(String uid) async {
    await syncAll(uid);
    await _listener?.cancel();
    _listener = _col(uid).snapshots().listen(
      (snapshot) async {
        final delta = {
          for (final change in snapshot.docChanges)
            if (change.type != DocumentChangeType.removed &&
                change.doc.data() != null)
              change.doc.id: change.doc.data()!,
        };
        if (delta.isEmpty) return;
        await _apply(
          uid,
          planCategorySync(
            uid: uid,
            local: _service.getAllCustomCategories(),
            remote: delta,
            remoteIsComplete: false,
          ),
        );
      },
      onError: (Object e) => debugPrint('Category sync listener error: $e'),
    );
  }

  Future<void> syncAll(String uid) async {
    final snapshot = await _col(uid).get();
    await _apply(
      uid,
      planCategorySync(
        uid: uid,
        local: _service.getAllCustomCategories(),
        remote: {for (final d in snapshot.docs) d.id: d.data()},
      ),
    );
  }

  Future<void> _apply(String uid, CategorySyncPlan plan) async {
    if (plan.isEmpty) return;
    for (final id in plan.deleteLocal) {
      await _service.deleteFromSync(id);
    }
    for (final c in plan.putLocal) {
      await _service.putFromSync(c);
    }
    for (final c in plan.upload) {
      push(uid, c);
    }
    if (plan.deleteLocal.isNotEmpty || plan.putLocal.isNotEmpty) {
      changed.value++;
    }
  }

  /// Send [category] to the account (fire-and-forget; Firestore queues it
  /// while offline).
  void push(String uid, CustomCategory category) {
    if (category.ownerUid != uid) {
      category.ownerUid = uid;
      unawaited(_service.putFromSync(category));
    }
    unawaited(
      _col(uid).doc(category.id).set(category.toJson()).catchError(
            (Object e) => debugPrint('Category push failed: $e'),
          ),
    );
  }

  /// Record a delete as a tombstone so other devices drop it too.
  void pushDelete(String uid, String id) {
    unawaited(
      _col(uid).doc(id).set({
        'id': id,
        'deleted': true,
        'updatedAt': DateTime.now().toIso8601String(),
      }).catchError((Object e) => debugPrint('Category delete push failed: $e')),
    );
  }

  Future<void> stop() async {
    await _listener?.cancel();
    _listener = null;
  }
}
