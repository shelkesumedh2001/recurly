import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/app_preferences.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/widgets/notification_primer.dart';

/// Pins the notification primer: who gets asked, when, at most how often,
/// and what the ask actually says.
///
/// The permission request used to run in `main()` before the first frame,
/// where an Android 13+ denial is permanent — so the rules deciding when
/// we're allowed to spend that one-shot prompt are the thing worth
/// guarding. They live in [primerDecision], kept pure precisely so they
/// can be pinned here without a platform channel: `hasPermission` reads
/// `Platform.isAndroid`, which is false on the test host, so anything
/// routed through the real service reports "granted" and passes vacuously.
///
/// The decision is an enum rather than a bool on purpose: the
/// skip-vs-retire distinction is what decides whether the one-shot flag
/// gets spent, and the truth table below pins it — most importantly that
/// a notifications-off user is SKIPPED (flag left pending), never RETIRED,
/// even when the OS permission happens to be granted.
///
/// The end-to-end flow (real system dialog, real grant) is a device-batch
/// case in DEV_STATUS — it can't be reached from a desktop VM.
void main() {
  Subscription fixture() => Subscription(
        id: 'netflix',
        name: 'Netflix',
        price: 15.99,
        billingCycle: BillingCycle.monthly,
        firstBillDate: DateTime(2026, 1, 22),
        category: SubscriptionCategory.entertainment,
        createdAt: DateTime(2026, 1, 22),
      );

  group('primerDecision', () {
    test('offers on a fresh install when permission is not yet granted', () {
      expect(
        primerDecision(AppPreferences(), hasPermission: false),
        PrimerDecision.offer,
      );
    });

    test('retires without a sheet when permission is already granted', () {
      expect(
        primerDecision(AppPreferences(), hasPermission: true),
        PrimerDecision.retire,
      );
    });

    test('skips once it has already been offered', () {
      expect(
        primerDecision(
          AppPreferences(notificationPrimerShown: true),
          hasPermission: false,
        ),
        PrimerDecision.skip,
      );
      expect(
        primerDecision(
          AppPreferences(notificationPrimerShown: true),
          hasPermission: true,
        ),
        PrimerDecision.skip,
      );
    });

    test('skips when reminders are switched off — permission not granted',
        () {
      expect(
        primerDecision(
          AppPreferences(notificationsEnabled: false),
          hasPermission: false,
        ),
        PrimerDecision.skip,
      );
    });

    test(
        'reminders off + permission granted is SKIP, not retire — the flag '
        'must stay pending so re-enabling reminders still earns a primer',
        () {
      // The regression this pins: a bool-shaped decision made the caller
      // re-derive why it was false, and that duplicated logic could spend
      // the primer on a notifications-off user.
      expect(
        primerDecision(
          AppPreferences(notificationsEnabled: false),
          hasPermission: true,
        ),
        PrimerDecision.skip,
      );
    });
  });

  group('AppPreferences.notificationPrimerShown', () {
    test('defaults to false on a fresh install so the primer runs once', () {
      expect(AppPreferences().notificationPrimerShown, isFalse);
    });

    test('survives copyWith without disturbing its neighbours', () {
      final updated = AppPreferences().copyWith(notificationPrimerShown: true);
      expect(updated.notificationPrimerShown, isTrue);
      expect(updated.notificationsEnabled, isTrue);
    });
  });

  group('leadDescriptionFor', () {
    test('names the earliest enabled reminder', () {
      expect(
        leadDescriptionFor(
          AppPreferences(
            reminder7DaysEnabled: true,
            reminder3DaysEnabled: true,
          ),
        ),
        '7 days before',
      );
    });

    test('matches the shipped default (3 days)', () {
      expect(leadDescriptionFor(AppPreferences()), '3 days before');
    });

    test('falls back to something true when every lead time is off', () {
      expect(
        leadDescriptionFor(
          AppPreferences(
            reminder7DaysEnabled: false,
            reminder3DaysEnabled: false,
            reminder1DayEnabled: false,
            reminderOnDayEnabled: false,
          ),
        ),
        'before it bills',
      );
    });
  });

  group('NotificationPrimerSheet', () {
    Future<bool?> pumpSheet(WidgetTester tester) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  answer = await showModalBottomSheet<bool>(
                    context: context,
                    builder: (_) => NotificationPrimerSheet(
                      subscription: fixture(),
                      leadDescription: '3 days before',
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('asks against the real subscription and its next bill date',
        (WidgetTester tester) async {
      // Pinned: the sheet shows `nextBillDate`, which walks the fixture's
      // Jan 22 anchor forward to the next occurrence after "today".
      await withClock(Clock.fixed(DateTime(2026, 7, 16)), () async {
        await pumpSheet(tester);

        expect(find.text('Want a heads-up before it bills?'), findsOneWidget);
        // The whole point of asking here rather than at cold start: the
        // question is about something the user just typed in.
        expect(find.textContaining('Netflix bills on Jul 22'), findsOneWidget);
        expect(find.textContaining('3 days before'), findsOneWidget);
      });
    });

    testWidgets('"Remind me" answers yes', (WidgetTester tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Remind me'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Want a heads-up before it bills?'), findsNothing);
    });

    testWidgets('"Not now" answers no', (WidgetTester tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Want a heads-up before it bills?'), findsNothing);
    });
  });
}
