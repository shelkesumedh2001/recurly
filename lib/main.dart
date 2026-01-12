import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/preferences_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize timezone database (required for scheduled notifications)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York')); // Set default timezone

    // Initialize database (includes Hive adapters)
    await DatabaseService().initialize();

    // Initialize preferences service
    await PreferencesService().initialize();

    // Initialize notification service
    await NotificationService().initialize();

    // Request notification permission (Android 13+)
    final notificationService = NotificationService();
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
    debugPrint('Failed to initialize app: $e');
  }

  // Run app with Riverpod
  runApp(
    const ProviderScope(
      child: RecurlyApp(),
    ),
  );
}

class RecurlyApp extends StatelessWidget {
  const RecurlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildWithTheme(
      builder: (lightTheme, darkTheme) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          // Theme configuration
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,

          // Home screen
          home: const HomeScreen(),
        );
      },
    );
  }
}
