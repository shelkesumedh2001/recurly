import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:recurly/main.dart';
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
  Future<void> setOnboardingComplete(bool complete) async {
    await PreferencesService().updatePreferences(
      PreferencesService().getPreferences().copyWith(
            onboardingComplete: complete,
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
    await setOnboardingComplete(true);

    await tester.pumpWidget(bootApp());
    await tester.pump();

    // The app shell built without crashing and reached the main navigation.
    expect(find.byType(RecurlyApp), findsOneWidget);
    expect(find.byType(MainNavigation), findsOneWidget);
  });

  testWidgets('Fresh install boots into the onboarding theme picker',
      (WidgetTester tester) async {
    await setOnboardingComplete(false);

    await tester.pumpWidget(bootApp());
    await tester.pump();

    // Lands on the onboarding theme picker, not the home shell.
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byType(MainNavigation), findsNothing);
  });

  testWidgets('Get Started persists onboarding completion',
      (WidgetTester tester) async {
    await setOnboardingComplete(false);

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
    await tester.pump(); // let the async pref write + rebuild settle

    expect(container.read(preferencesProvider).onboardingComplete, isTrue);
  });
}
