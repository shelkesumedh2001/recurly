import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/services/database_service.dart';
import 'package:recurly/services/sync_queue.dart';
import 'package:recurly/services/sync_service.dart';

/// Exercises the sync merge + offline-queue drain logic against
/// fake_cloud_firestore — the paths the manual 2-device checklist covers
/// by hand: last-write-wins, tombstone purge, and delete-before-merge.
void main() {
  const uid = 'user-1';
  late Directory tempDir;
  late Box<Subscription> subsBox;
  late Box<dynamic> queueBox;
  late FakeFirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> remoteSubs() =>
      firestore.collection('users').doc(uid).collection('subscriptions');

  Subscription sub(
    String id, {
    DateTime? updatedAt,
    DateTime? deletedAt,
    String name = 'Sub',
  }) {
    return Subscription(
      id: id,
      name: name,
      price: 9.99,
      billingCycle: BillingCycle.monthly,
      firstBillDate: DateTime(2026, 6, 1),
      category: SubscriptionCategory.entertainment,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      ownerUid: uid,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recurly_sync_fs_');
    Hive.init(tempDir.path);
    DatabaseService.registerAdapters();
    subsBox = await Hive.openBox<Subscription>('sync_fs_subs');
    queueBox = await Hive.openBox<dynamic>('sync_fs_queue');

    DatabaseService().debugSetSubscriptionsBox(subsBox);
    SyncQueue.debugSetInstance(SyncQueue.withBox(queueBox));
    firestore = FakeFirebaseFirestore();
    SyncService.debugFirestoreOverride = firestore;
  });

  tearDown(() async {
    SyncService().dispose();
    SyncService.debugFirestoreOverride = null;
    SyncQueue.debugSetInstance(null);
    await subsBox.deleteFromDisk();
    await queueBox.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('forceSync merge (last-write-wins)', () {
    test('remote-only sub lands locally', () async {
      await remoteSubs().doc('r1').set(sub('r1', name: 'Remote').toJson());

      await SyncService().forceSync(uid);

      expect(subsBox.get('r1')?.name, 'Remote');
    });

    test('local-only sub is pushed to remote', () async {
      await subsBox.put('l1', sub('l1', name: 'Local'));

      await SyncService().forceSync(uid);

      final doc = await remoteSubs().doc('l1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'Local');
    });

    test('newer remote wins over older local', () async {
      await subsBox.put(
        's1',
        sub('s1', name: 'Old local', updatedAt: DateTime(2026, 7, 1)),
      );
      await remoteSubs().doc('s1').set(
            sub('s1', name: 'New remote', updatedAt: DateTime(2026, 7, 2))
                .toJson(),
          );

      await SyncService().forceSync(uid);

      expect(subsBox.get('s1')?.name, 'New remote');
    });

    test('newer local wins and is pushed to remote', () async {
      await subsBox.put(
        's1',
        sub('s1', name: 'New local', updatedAt: DateTime(2026, 7, 2)),
      );
      await remoteSubs().doc('s1').set(
            sub('s1', name: 'Old remote', updatedAt: DateTime(2026, 7, 1))
                .toJson(),
          );

      await SyncService().forceSync(uid);

      expect(subsBox.get('s1')?.name, 'New local');
      final doc = await remoteSubs().doc('s1').get();
      expect(doc.data()?['name'], 'New local');
    });

    test('newer remote soft-delete propagates to local', () async {
      await subsBox.put(
        's1',
        sub('s1', updatedAt: DateTime(2026, 7, 1)),
      );
      await remoteSubs().doc('s1').set(
            sub(
              's1',
              updatedAt: DateTime(2026, 7, 2),
              deletedAt: DateTime(2026, 7, 2),
            ).toJson(),
          );

      await SyncService().forceSync(uid);

      expect(subsBox.get('s1')?.deletedAt, isNotNull);
    });

    test('soft-deletes older than 30 days are purged remote AND local',
        () async {
      final ancient = DateTime.now().subtract(const Duration(days: 45));
      await subsBox.put(
        'dead',
        sub('dead', updatedAt: ancient, deletedAt: ancient),
      );
      await remoteSubs()
          .doc('dead')
          .set(sub('dead', updatedAt: ancient, deletedAt: ancient).toJson());

      await SyncService().forceSync(uid);

      expect(subsBox.get('dead'), isNull);
      final doc = await remoteSubs().doc('dead').get();
      expect(doc.exists, isFalse);
    });
  });

  group('drainPendingOps (S1 offline write-queue)', () {
    test('queued delete removes the remote doc and clears the op', () async {
      await remoteSubs().doc('gone').set(sub('gone').toJson());
      final queue = SyncQueue();
      await queue.enqueueDelete(uid, 'gone');

      await SyncService().drainPendingOps(uid);

      final doc = await remoteSubs().doc('gone').get();
      expect(doc.exists, isFalse);
      expect(queue.isEmpty, isTrue);
    });

    test('queued push sends the CURRENT local state, then clears', () async {
      await subsBox.put('p1', sub('p1', name: 'Latest name'));
      final queue = SyncQueue();
      await queue.enqueuePush(uid, 'p1');

      await SyncService().drainPendingOps(uid);

      final doc = await remoteSubs().doc('p1').get();
      expect(doc.data()?['name'], 'Latest name');
      expect(queue.isEmpty, isTrue);
    });

    test('push op whose sub vanished locally is dropped without pushing',
        () async {
      final queue = SyncQueue();
      await queue.enqueuePush(uid, 'ghost');

      await SyncService().drainPendingOps(uid);

      final doc = await remoteSubs().doc('ghost').get();
      expect(doc.exists, isFalse);
      expect(queue.isEmpty, isTrue);
    });

    test('ops for another uid are left queued', () async {
      final queue = SyncQueue();
      await queue.enqueueDelete('someone-else', 'x1');

      await SyncService().drainPendingOps(uid);

      expect(queue.opsForUser('someone-else'), hasLength(1));
    });

    test(
        'forceSync drains a queued delete BEFORE merging, so the deleted '
        'sub cannot resurrect locally', () async {
      // Sub was hard-deleted locally while offline: gone from Hive,
      // delete op queued, doc still present remotely.
      await remoteSubs().doc('zombie').set(sub('zombie').toJson());
      await SyncQueue().enqueueDelete(uid, 'zombie');

      await SyncService().forceSync(uid);

      expect(subsBox.get('zombie'), isNull,
          reason: 'merge must not re-download the doc the queue deletes',);
      final doc = await remoteSubs().doc('zombie').get();
      expect(doc.exists, isFalse);
    });
  });
}
