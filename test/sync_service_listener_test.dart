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
}
