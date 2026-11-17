import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:recurly/models/custom_category.dart';
import 'package:recurly/services/category_sync.dart';
import 'package:recurly/services/custom_category_service.dart';
import 'package:recurly/services/database_service.dart';

void main() {
  const uid = 'me';
  final t0 = DateTime(2026, 11, 1);
  final t1 = DateTime(2026, 11, 2);

  CustomCategory cat(String id, {DateTime? at, String name = 'Pets', String? owner}) =>
      CustomCategory(
        id: id,
        name: name,
        icon: '🐶',
        createdAt: t0,
        updatedAt: at ?? t0,
        ownerUid: owner,
      );

  Map<String, dynamic> doc(String id, {DateTime? at, String name = 'Pets'}) =>
      cat(id, at: at, name: name).toJson();

  group('planCategorySync', () {
    test('remote-only lands locally, tagged with the account', () {
      final plan = planCategorySync(uid: uid, local: [], remote: {'a': doc('a')});
      expect(plan.putLocal.single.id, 'a');
      expect(plan.putLocal.single.ownerUid, uid);
      expect(plan.upload, isEmpty);
    });

    test('never-synced local is uploaded; on a delta it is left alone', () {
      final local = [cat('a')];
      expect(
        planCategorySync(uid: uid, local: local, remote: {}).upload.single.id,
        'a',
      );
      expect(
        planCategorySync(
          uid: uid,
          local: local,
          remote: {},
          remoteIsComplete: false,
        ).isEmpty,
        isTrue,
      );
    });

    test('newest wins both ways', () {
      final remoteNewer = planCategorySync(
        uid: uid,
        local: [cat('a', owner: uid)],
        remote: {'a': doc('a', at: t1, name: 'Animals')},
      );
      expect(remoteNewer.putLocal.single.name, 'Animals');

      final localNewer = planCategorySync(
        uid: uid,
        local: [cat('a', at: t1, owner: uid, name: 'Mine')],
        remote: {'a': doc('a')},
      );
      expect(localNewer.upload.single.name, 'Mine');
      expect(localNewer.putLocal, isEmpty);
    });

    test('same version: nothing to do', () {
      final plan = planCategorySync(
        uid: uid,
        local: [cat('a', owner: uid)],
        remote: {'a': doc('a')},
      );
      expect(plan.isEmpty, isTrue);
    });

    test('a tombstone removes it here, unless edited here after', () {
      final tomb = {'id': 'a', 'deleted': true, 'updatedAt': t1.toIso8601String()};
      expect(
        planCategorySync(uid: uid, local: [cat('a', owner: uid)], remote: {'a': tomb})
            .deleteLocal,
        ['a'],
      );
      final later = planCategorySync(
        uid: uid,
        local: [cat('a', owner: uid, at: DateTime(2026, 11, 3))],
        remote: {'a': tomb},
      );
      expect(later.deleteLocal, isEmpty);
      expect(later.upload.single.id, 'a');
    });

    test("another account's categories are dropped, not uploaded", () {
      final plan = planCategorySync(
        uid: uid,
        local: [cat('x', owner: 'someone-else')],
        remote: {},
      );
      expect(plan.deleteLocal, ['x']);
      expect(plan.upload, isEmpty);
    });
  });

  group('CategorySync against Firestore', () {
    late Directory dir;
    late Box<CustomCategory> box;
    late FakeFirebaseFirestore fs;
    late CategorySync sync;
    final service = CustomCategoryService();

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('recurly_cat_sync_');
      Hive.init(dir.path);
      DatabaseService.registerAdapters();
      box = await Hive.openBox<CustomCategory>('cat_sync_test');
      service.debugSetBox(box);
      fs = FakeFirebaseFirestore();
      sync = CategorySync(() => fs, service);
    });

    tearDown(() async {
      await sync.stop();
      service.debugSetBox(null);
      await box.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('a category made on one device reaches the other', () async {
      // Device 1 has a category made before sign-in.
      await box.put('a', cat('a'));
      await sync.syncAll(uid);
      await Future<void>.delayed(Duration.zero);
      final remote =
          await fs.collection('users').doc(uid).collection('categories').get();
      expect(remote.docs.single.data()['name'], 'Pets');
      expect(box.get('a')!.ownerUid, uid);

      // Device 2 (fresh box) signs in and receives it.
      await box.clear();
      await sync.syncAll(uid);
      expect(box.get('a')?.name, 'Pets');
    });

    test('a delete leaves a tombstone so the other device drops it', () async {
      await box.put('a', cat('a', owner: uid));
      await sync.syncAll(uid);
      await Future<void>.delayed(Duration.zero);

      sync.pushDelete(uid, 'a');
      await Future<void>.delayed(Duration.zero);
      // The other device still has it, offline when it was deleted.
      await sync.syncAll(uid);
      expect(box.get('a'), isNull);
    });
  });
}
