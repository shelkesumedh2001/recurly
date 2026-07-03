import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'providers/theme_providers.dart';
import 'screens/main_navigation.dart';
import 'services/auth_service.dart';
import 'services/budget_service.dart';
import 'services/credit_card_service.dart';
import 'services/currency_service.dart';
import 'services/custom_category_service.dart';
import 'services/database_service.dart';
import 'services/home_widget_service.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'services/sync_service.dart';
import 'services/theme_service.dart';
import 'utils/constants.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

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

    // Request notification permission (Android 13+)
    final hasPermission = await notificationService.hasPermission();
    if (!hasPermission) {
      await notificationService.requestPermission();
    }

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

  // Initialize sync for signed-in users
  try {
    final authService = AuthService();
    final user = authService.currentUser;
    if (user != null) {
      final profile = await authService.getUserProfile(user.uid);
      if (profile != null) {
        // Sync for all signed-in users
        await SyncService().initialize(user.uid);
        debugPrint('Sync service initialized for ${user.uid}');

        // Household sync if in a household
        if (profile.householdId != null) {
          await SyncService().initializeHouseholdSync(user.uid, profile.householdId!);
          debugPrint('Household sync initialized');
        }
      }
    }
  } catch (e) {
    debugPrint('Failed to initialize sync service: $e');
  }

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

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      navigatorKey: rootNavigatorKey,

      // Theme configuration from providers
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,

      // Main navigation with bottom nav bar
      home: const MainNavigation(),
    );
  }
}
