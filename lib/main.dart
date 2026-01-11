import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  try {
    await DatabaseService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize database: $e');
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
