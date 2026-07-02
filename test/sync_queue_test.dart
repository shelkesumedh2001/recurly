import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:recurly/services/sync_queue.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recurly_sync_queue_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('sync_queue_test');
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('SyncQueue enqueue/coalesce', () {
    test('enqueuePush stores a retrievable push op', () async {
      final queue = SyncQueue.withBox(box);

      await queue.enqueuePush('uidA', 'sub1');

      final ops = queue.opsForUser('uidA');
      expect(ops, hasLength(1));
      expect(ops.single.subId, 'sub1');
      expect(ops.single.op, SyncQueue.opPush);
    });

    test('later delete op replaces a queued push for the same sub', () async {
      final queue = SyncQueue.withBox(box);

      await queue.enqueuePush('uidA', 'sub1');
      await queue.enqueueDelete('uidA', 'sub1');

      final ops = queue.opsForUser('uidA');
      expect(ops, hasLength(1));
      expect(ops.single.op, SyncQueue.opDelete);
    });

    test('later push op replaces a queued delete for the same sub', () async {
      final queue = SyncQueue.withBox(box);

      await queue.enqueueDelete('uidA', 'sub1');
      await queue.enqueuePush('uidA', 'sub1');

      final ops = queue.opsForUser('uidA');
      expect(ops, hasLength(1));
      expect(ops.single.op, SyncQueue.opPush);
    });
  });

  group('SyncQueue per-user isolation', () {
    test('opsForUser only returns the given uid\'s ops', () async {
      final queue = SyncQueue.withBox(box);

      await queue.enqueuePush('uidA', 'sub1');
      await queue.enqueueDelete('uidB', 'sub2');

      expect(queue.opsForUser('uidA').map((o) => o.subId), ['sub1']);
      expect(queue.opsForUser('uidB').map((o) => o.subId), ['sub2']);
      expect(queue.opsForUser('uidC'), isEmpty);
    });
  });

  group('SyncQueue ordering', () {
    test('opsForUser returns oldest first', () async {
      var tick = DateTime(2026, 1, 1);
      final queue = SyncQueue.withBox(
        box,
        clock: () {
          tick = tick.add(const Duration(minutes: 1));
          return tick;
        },
      );

      await queue.enqueuePush('uidA', 'first');
      await queue.enqueuePush('uidA', 'second');
      await queue.enqueueDelete('uidA', 'third');

      expect(
        queue.opsForUser('uidA').map((o) => o.subId),
        ['first', 'second', 'third'],
      );
    });
  });

  group('SyncQueue remove/purge/cap', () {
    test('remove drops the op', () async {
      final queue = SyncQueue.withBox(box);
      await queue.enqueuePush('uidA', 'sub1');

      await queue.remove('sub1');

      expect(queue.isEmpty, isTrue);
    });

    test('purgeStale drops ops older than 30 days, keeps fresh ones',
        () async {
      var now = DateTime(2026, 1, 1);
      final queue = SyncQueue.withBox(box, clock: () => now);

      await queue.enqueuePush('uidA', 'old');
      now = DateTime(2026, 2, 15); // 45 days later
      await queue.enqueuePush('uidA', 'fresh');

      await queue.purgeStale();

      expect(queue.opsForUser('uidA').map((o) => o.subId), ['fresh']);
    });

    test('cap evicts oldest ops beyond maxOps', () async {
      var tick = DateTime(2026, 1, 1);
      final queue = SyncQueue.withBox(
        box,
        clock: () {
          tick = tick.add(const Duration(seconds: 1));
          return tick;
        },
      );

      for (var i = 0; i < SyncQueue.maxOps + 3; i++) {
        await queue.enqueuePush('uidA', 'sub$i');
      }

      expect(queue.length, SyncQueue.maxOps);
      final ids = queue.opsForUser('uidA').map((o) => o.subId).toList();
      expect(ids.first, 'sub3', reason: 'sub0..sub2 evicted as oldest');
      expect(ids.last, 'sub${SyncQueue.maxOps + 2}');
    });
  });

  group('SyncQueue persistence', () {
    test('ops survive box close/reopen', () async {
      final queue = SyncQueue.withBox(box);
      await queue.enqueueDelete('uidA', 'sub1');

      await box.close();
      box = await Hive.openBox<dynamic>('sync_queue_test');
      final reopened = SyncQueue.withBox(box);

      final ops = reopened.opsForUser('uidA');
      expect(ops, hasLength(1));
      expect(ops.single.op, SyncQueue.opDelete);
    });
  });
}
