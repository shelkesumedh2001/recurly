import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/services/sync_service.dart';

void main() {
  group('SyncService remote-data-change ticker', () {
    test(
      'SyncService exposes remoteDataChangeTicker as ValueNotifier<int> (compile-time contract)',
      () {
        // Compile-time check: referencing the field through a typed local
        // ensures the API exists and has the expected shape. The file will
        // fail to compile pre-fix (when SyncService only had a
        // `VoidCallback? _onRemoteDataChanged` private field + setter).
        //
        // We cannot construct SyncService() at runtime in a unit test — its
        // field initializer resolves FirebaseFirestore.instance, which
        // requires Firebase.initializeApp(). The compile-time check is the
        // strongest assertion possible here.
        // ignore: unused_element, prefer_function_declarations_over_variables
        final ValueNotifier<int> Function(SyncService) resolveTicker =
            (s) => s.remoteDataChangeTicker;
        expect(resolveTicker, isNotNull);
      },
    );

    test(
      'ValueNotifier<int> ticker notifies every registered listener on increment '
      '(contract: no single-callback overwrite)',
      () {
        final ticker = ValueNotifier<int>(0);
        var callsA = 0;
        var callsB = 0;
        void listenerA() => callsA++;
        void listenerB() => callsB++;

        ticker
          ..addListener(listenerA)
          ..addListener(listenerB);

        ticker.value++;

        expect(callsA, 1);
        expect(callsB, 1);

        ticker
          ..removeListener(listenerA)
          ..removeListener(listenerB)
          ..dispose();
      },
    );

    test(
      'removing one listener does not affect other subscribers',
      () {
        final ticker = ValueNotifier<int>(0);
        var callsA = 0;
        var callsB = 0;
        void listenerA() => callsA++;
        void listenerB() => callsB++;

        ticker
          ..addListener(listenerA)
          ..addListener(listenerB);
        ticker.value++;

        ticker.removeListener(listenerA);
        ticker.value++;

        expect(callsA, 1, reason: 'A removed before second increment');
        expect(callsB, 2, reason: 'B stayed subscribed through both increments');

        ticker
          ..removeListener(listenerB)
          ..dispose();
      },
    );
  });

  group('locally-deleted-id set eviction (bug #6)', () {
    // SyncService can't be constructed in a unit test (Firebase), so these
    // assert the properties the `_markLocallyDeleted` cap relies on.
    test('Set literal is insertion-ordered so `first` is the oldest id', () {
      final ids = <String>{};
      for (var i = 0; i < 5; i++) {
        ids.add('id$i');
      }
      expect(ids.first, 'id0');
      ids.remove(ids.first);
      expect(ids.first, 'id1');
    });

    test('capped FIFO eviction keeps only the newest N ids', () {
      final ids = <String>{};
      const cap = 3;
      void mark(String id) {
        ids.add(id);
        while (ids.length > cap) {
          ids.remove(ids.first);
        }
      }

      for (var i = 0; i < 6; i++) {
        mark('id$i');
      }

      expect(ids, {'id3', 'id4', 'id5'});
      expect(ids.length, cap);
    });
  });
}
