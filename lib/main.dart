import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'providers/preferences_providers.dart';
import 'providers/theme_providers.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';
import 'services/budget_service.dart';
import 'services/credit_card_service.dart';
import 'services/currency_service.dart';
import 'services/custom_category_service.dart';
import 'services/database_service.dart';
import 'services/home_widget_service.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'services/theme_service.dart';
import 'utils/constants.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter defaults to 60Hz on many Android devices — ask for the
  // display's highest refresh rate (no-op where unsupported).
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {
    debugPrint('Could not set high refresh rate: $e');
  }

  // Initialize timezone database (required for scheduled notifications)
  tz.initializeTimeZones();
  try {
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint('Timezone initialized: $timeZoneName');
  } catch (e) {
    debugPrint('Failed to get local timezone, falling back to UTC: $e');
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized');
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }

  // Initialize database (includes Hive adapters) - REQUIRED
  await DatabaseService().initialize();

  // Purge subscriptions that have sat in Recently Deleted past the 30-day
  // window (best-effort; failures shouldn't block startup).
  try {
    final purged = await DatabaseService().cleanupOldDeletedSubscriptions();
    if (purged > 0) {
      debugPrint('Purged $purged expired recently-deleted subscription(s)');
    }
  } catch (e) {
    debugPrint('Recently-deleted cleanup failed: $e');
  }

  // Initialize preferences service - REQUIRED
  await PreferencesService().initialize();

  // Count this cold start, so the review prompt can stay off first runs.
  // Best-effort: a failed counter must never block startup.
  try {
    final prefsService = PreferencesService();
    final prefs = prefsService.getPreferences();
    await prefsService.updatePreferences(
      prefs.copyWith(sessionCount: prefs.sessionCount + 1),
    );
  } catch (e) {
    debugPrint('Failed to record session: $e');
  }

  // Initialize optional services (failures logged but don't block app)
  try {
    await ThemeService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize theme service: $e');
  }

  try {
    await BudgetService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize budget service: $e');
  }

  try {
    await CustomCategoryService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize custom category service: $e');
  }

  try {
    await CreditCardService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize credit card service: $e');
  }

  try {
    await CurrencyService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize currency service: $e');
  }

  // Initialize home widget service
  try {
    final homeWidgetService = HomeWidgetService();
    await homeWidgetService.initialize();
    // Update widget with current data
    await homeWidgetService.updateWidgetData();
  } catch (e) {
    debugPrint('Failed to initialize home widget service: $e');
  }

  // Initialize and configure notification service
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // No permission request here by design. It used to run at this point —
    // before runApp(), so the OS prompt appeared over a blank screen and
    // startup blocked on the user's answer. `maybeShowNotificationPrimer`
    // now asks after the first subscription is saved, where the request
    // has context. See widgets/notification_primer.dart.

    // Reschedule all notifications on app start (handles app restart, date changes)
    final preferences = PreferencesService().getPreferences();
    if (preferences.notificationsEnabled) {
      final subscriptions = DatabaseService().getActiveSubscriptions();
      await notificationService.rescheduleAllNotifications(
        subscriptions,
        preferences,
        cards: CreditCardService().getAllCards(),
      );
    }
  } catch (e) {
    debugPrint('Failed to initialize notification service: $e');
  }

  // No sync here by design. It used to run at this point — a profile fetch,
  // a full two-way Firestore sync, and household-listener setup, all awaited
  // before runApp(), which held signed-in users on the splash screen for as
  // long as the network took (seconds), and then syncInitProvider ran the
  // same sync again once the UI was up. The app is offline-first: Hive
  // already has the data, so the UI renders immediately and
  // syncInitProvider/householdSyncProvider (held alive from HomeScreen's
  // initState) run the one and only sync in the background.

  // Run app with Riverpod
  runApp(
    const ProviderScope(
      child: RecurlyApp(),
    ),
  );
}

/// App-wide ScaffoldMessenger key (kept for non-toast snackbars elsewhere).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// App-wide Navigator key — gives `showAppToast` access to the root
/// Overlay so the toast lifecycle is independent of any Scaffold/
/// ScaffoldMessenger interaction quirks.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class RecurlyApp extends ConsumerWidget {
  const RecurlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme providers for reactive updates
    final lightTheme = ref.watch(lightThemeProvider);
    final darkTheme = ref.watch(darkThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    // First-run gate: show the theme-picker onboarding until it's completed.
    final onboardingComplete = ref.watch(
      preferencesProvider.select((p) => p.onboardingComplete),
    );

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      navigatorKey: rootNavigatorKey,

      // Theme configuration from providers
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,

      // First-run onboarding (theme picker) → then the main navigation.
      home: onboardingComplete
          ? const MainNavigation()
          : const OnboardingScreen(),
    );
  }
}
