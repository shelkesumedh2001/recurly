import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'screens/main_navigation.dart';
import 'services/auth_service.dart';
import 'services/budget_service.dart';
import 'services/currency_service.dart';
import 'services/custom_category_service.dart';
import 'services/database_service.dart';
import 'services/home_widget_service.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'services/sync_service.dart';
import 'services/theme_service.dart';
import 'providers/theme_providers.dart';
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

      // Theme configuration from providers
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,

      // Main navigation with bottom nav bar
      home: const MainNavigation(),
    );
  }
}
