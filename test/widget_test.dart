import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:recurly/main.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/providers/auth_providers.dart';
import 'package:recurly/providers/preferences_providers.dart';
import 'package:recurly/screens/main_navigation.dart';
import 'package:recurly/screens/onboarding_screen.dart';
import 'package:recurly/services/budget_service.dart';
import 'package:recurly/services/credit_card_service.dart';
import 'package:recurly/services/currency_service.dart';
import 'package:recurly/services/custom_category_service.dart';
import 'package:recurly/services/database_service.dart';
import 'package:recurly/services/preferences_service.dart';
import 'package:recurly/services/sync_service.dart';
import 'package:recurly/services/theme_service.dart';
import 'package:recurly/widgets/add_subscription_sheet.dart';

/// Boots the real app shell (RecurlyApp → MainNavigation → HomeScreen)
/// against mocked Firebase, a fake Firestore, and temp-dir Hive boxes.
/// Catches provider-wiring and startup regressions the unit tests can't.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();

    tempDir = await Directory.systemTemp.createTemp('recurly_smoke_');
    Hive.init(tempDir.path);
    DatabaseService.registerAdapters();

    // Services normally initialized by main(): each just opens a Hive box,
    // which works fine on a plain Hive.init (no path_provider needed).
    DatabaseService().debugSetSubscriptionsBox(
      await Hive.openBox<Subscription>('smoke_subscriptions'),
    );
    await PreferencesService().initialize();
    await ThemeService().initialize();
    await BudgetService().initialize();
    await CustomCategoryService().initialize();
    await CreditCardService().initialize();
    await CurrencyService().initialize();

    SyncService.debugFirestoreOverride = FakeFirebaseFirestore();
  });

  tearDownAll(() async {
    SyncService.debugFirestoreOverride = null;
    await tempDir.delete(recursive: true);
  });

  /// Seed the first-run onboarding flag so a test controls whether it boots
  /// into onboarding or straight into the home shell.
  ///
  /// Must go through [WidgetTester.runAsync]: the Hive put is real disk I/O,
  /// which never completes inside testWidgets' FakeAsync zone — awaiting it
  /// directly hangs the test until the 10-minute timeout.
  Future<void> setOnboardingComplete(WidgetTester tester, bool complete) async {
    await tester.runAsync(
      () => PreferencesService().updatePreferences(
        PreferencesService().getPreferences().copyWith(
              onboardingComplete: complete,
            ),
      ),
    );
  }

  Widget bootApp() => ProviderScope(
        overrides: [
          // Signed-out session: FirebaseAuth's real stream needs platform
          // channels that don't exist in tests.
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const RecurlyApp(),
      );

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Already-onboarded user boots straight into the home shell.
    await setOnboardingComplete(tester, true);

    await tester.pumpWidget(bootApp());
    await tester.pump();

    // The app shell built without crashing and reached the main navigation.
    expect(find.byType(RecurlyApp), findsOneWidget);
    expect(find.byType(MainNavigation), findsOneWidget);
  });

  testWidgets('Fresh install boots into the onboarding theme picker',
      (WidgetTester tester) async {
    await setOnboardingComplete(tester, false);

    await tester.pumpWidget(bootApp());
    await tester.pump();

    // Lands on the onboarding theme picker, not the home shell.
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byType(MainNavigation), findsNothing);
  });

  testWidgets('Get Started persists onboarding completion',
      (WidgetTester tester) async {
    await setOnboardingComplete(tester, false);

    // Pump the screen directly (not the full app shell) so the tap's effect
    // is observable without mounting MainNavigation's tabs/timers.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();

    expect(container.read(preferencesProvider).onboardingComplete, isFalse);

    await tester.tap(find.text('Get Started'));
    // The notifier persists to Hive (real disk I/O) BEFORE flipping state,
    // and that write only completes on the real event loop — poll for it
    // inside runAsync, bounded so a regression fails fast instead of hanging.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!container.read(preferencesProvider).onboardingComplete &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(container.read(preferencesProvider).onboardingComplete, isTrue);
  });

  /// Next-bill-date field. The anchor arithmetic it feeds is pinned in
  /// billing_cycle_test ("the anchor contract"); what's guarded here is the
  /// wiring — that the date can't be skipped, that a day chip fills it, and
  /// that a stale date can't survive a cycle change. A successful save
  /// can't be driven from here: `addSubscription` schedules notifications,
  /// and NotificationService.initialize() needs platform channels that
  /// don't exist on the test host. That path is in the DEV_STATUS device
  /// batch.
  group('add sheet — next bill date', () {
    // Pinned early in the month on purpose. Material caps a bottom sheet
    // at 640dp wide, so the lazy chip row only ever builds roughly the
    // first dozen days — with the clock late in the month, every "still
    // ahead" day would sit past the end of the built range.
    final now = DateTime(2026, 7, 2);

    Future<void> openSheet(WidgetTester tester) async {
      // The form is taller than the default 800x600 surface, which parks
      // SAVE off-screen where taps silently miss. Widening past 640 buys
      // nothing — Material caps the sheet there.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const AddSubscriptionSheet(),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('starts empty rather than defaulting to a wrong date',
        (WidgetTester tester) async {
      await withClock(Clock.fixed(now), () async {
        await openSheet(tester);

        // The regression this replaces: the field defaulted to today and
        // was silently accepted, putting the next bill a full cycle out.
        expect(find.text('Select date'), findsOneWidget);
      });
    });

    testWidgets('blocks save until the next bill date is given',
        (WidgetTester tester) async {
      await withClock(Clock.fixed(now), () async {
        await openSheet(tester);

        await tester.tap(find.text('SAVE'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Pick when this bills next so reminders land on the right day',
          ),
          findsOneWidget,
        );
        // Still open — nothing was written.
        expect(find.byType(AddSubscriptionSheet), findsOneWidget);
      });
    });

    testWidgets('a day chip fills the date and clears the error',
        (WidgetTester tester) async {
      await withClock(Clock.fixed(now), () async {
        await openSheet(tester);
        await tester.tap(find.text('SAVE'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('8'));
        await tester.pumpAndSettle();

        // The 8th is still ahead of the 2nd, so it means this month.
        expect(find.text('Wed, Jul 8, 2026'), findsOneWidget);
        expect(find.textContaining('Bills in 6 days'), findsOneWidget);
        expect(
          find.text(
            'Pick when this bills next so reminders land on the right day',
          ),
          findsNothing,
        );
      });
    });

    testWidgets('a day already past this month resolves to next month',
        (WidgetTester tester) async {
      await withClock(Clock.fixed(now), () async {
        await openSheet(tester);

        // The 1st has been and gone; the NEXT one is in August.
        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();

        expect(find.text('Sat, Aug 1, 2026'), findsOneWidget);
      });
    });

    testWidgets('free trials hide the field — the trial end is the first bill',
        (WidgetTester tester) async {
      await withClock(Clock.fixed(now), () async {
        await openSheet(tester);
        expect(find.text('Next bill date'), findsOneWidget);

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();

        expect(find.text('Next bill date'), findsNothing);
      });
    });

    Future<void> switchToWeekly(WidgetTester tester) async {
      await tester.tap(find.byType(DropdownButtonFormField<BillingCycle>));
      await tester.pumpAndSettle();
      // Both the closed button's label and the open menu item match, so
      // take the menu item.
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
    }

    testWidgets('shrinking the cycle drops a date it can no longer reach',
        (WidgetTester tester) async {
      await withClock(Clock.fixed(now), () async {
        await openSheet(tester);

        // Jul 10 is fine monthly (window reaches Aug 2) but unreachable
        // weekly (which reaches only Jul 9).
        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();
        expect(find.text('Select date'), findsNothing);

        await switchToWeekly(tester);

        // Kept, it would have saved an anchor resolving to the wrong day.
        expect(find.text('Select date'), findsOneWidget);
      });
    });

    testWidgets('switching a trial off drops the stale trial-end date',
        (WidgetTester tester) async {
      await withClock(Clock.fixed(now), () async {
        // Editing a trial seeds the field from nextBillDate, which for a
        // trial IS the trial end — potentially months out, far outside the
        // window a monthly sub can represent. Switching the trial off
        // reveals that field, and a stale value there would save an anchor
        // resolving a whole cycle early.
        final trialSub = Subscription(
          id: 't1',
          name: 'Trial',
          price: 0,
          billingCycle: BillingCycle.monthly,
          firstBillDate: DateTime(2026, 7, 1),
          category: SubscriptionCategory.entertainment,
          createdAt: DateTime(2026, 7, 1),
          isFreeTrial: true,
          trialEndDate: DateTime(2026, 12, 1),
          priceAfterTrial: 9.99,
        );

        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(null)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: AddSubscriptionSheet(subscription: trialSub),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Next bill date'), findsNothing);

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();

        expect(find.text('Next bill date'), findsOneWidget);
        expect(find.text('Select date'), findsOneWidget);
        expect(find.textContaining('Dec 1, 2026'), findsNothing);
      });
    });

    testWidgets('shrinking the cycle keeps a date that is still reachable',
        (WidgetTester tester) async {
      await withClock(Clock.fixed(now), () async {
        await openSheet(tester);

        // Jul 8 sits inside the weekly window (through Jul 9) too.
        await tester.tap(find.text('8'));
        await tester.pumpAndSettle();

        await switchToWeekly(tester);

        expect(find.text('Wed, Jul 8, 2026'), findsOneWidget);
      });
    });
  });

  testWidgets('template can be re-picked after dismissing the add sheet',
      (WidgetTester tester) async {
    // Regression: chip taps used to route through a global provider that
    // survived the sheet's dismissal. Re-tapping the same service then wrote
    // an identical value, which never notified, so the form stayed empty.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AddSubscriptionSheet(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> openSheetAndPickNetflix() async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Netflix'),
        findsOneWidget,
        reason: 'tapping the Netflix template must fill the name field',
      );
    }

    await openSheetAndPickNetflix();

    // Dismiss the sheet the way the system back button does.
    Navigator.of(tester.element(find.byType(AddSubscriptionSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(AddSubscriptionSheet), findsNothing);

    await openSheetAndPickNetflix();
  });
}
