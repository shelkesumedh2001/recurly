import 'package:flutter/material.dart';
// import 'package:dynamic_color/dynamic_color.dart'; // Temporarily disabled
import '../utils/constants.dart';

/// Material 3 theme configuration
class AppTheme {
  // Primary color scheme
  static const _primaryColor = Color(0xFF6750A4);
  static const _secondaryColor = Color(0xFF625B71);
  static const _tertiaryColor = Color(0xFF7D5260);

  /// Get the light theme
  static ThemeData getLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // Typography
      textTheme: _getTextTheme(),

      // Card theme
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing24,
          vertical: AppConstants.spacing8,
        ),
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppConstants.radiusLarge),
            topRight: Radius.circular(AppConstants.radiusLarge),
          ),
        ),
        showDragHandle: true,
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
      ),

      // App bar theme
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 3,
        surfaceTintColor: colorScheme.surfaceTint,
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing8,
        ),
      ),

      // Animation durations
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Get the dark theme
  static ThemeData getDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // Typography
      textTheme: _getTextTheme(),

      // Card theme
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing24,
          vertical: AppConstants.spacing8,
        ),
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppConstants.radiusLarge),
            topRight: Radius.circular(AppConstants.radiusLarge),
          ),
        ),
        showDragHandle: true,
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
      ),

      // App bar theme
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 3,
        surfaceTintColor: colorScheme.surfaceTint,
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing8,
        ),
      ),

      // Animation durations
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Material 3 text theme
  static TextTheme _getTextTheme() {
    return const TextTheme(
      // Display styles
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
      ),

      // Headline styles
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),

      // Title styles
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),

      // Body styles
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.4,
      ),

      // Label styles
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Get color for renewal urgency
  static Color getRenewalUrgencyColor(
    BuildContext context,
    int daysUntilRenewal,
  ) {
    final theme = Theme.of(context);

    if (daysUntilRenewal < AppConstants.renewalUrgentThreshold) {
      return theme.colorScheme.error;
    } else if (daysUntilRenewal < AppConstants.renewalWarningThreshold) {
      return theme.colorScheme.tertiary;
    } else {
      return theme.colorScheme.primary;
    }
  }

  /// Create theme wrapper (Material You will be added later)
  static Widget buildWithTheme({
    required Widget Function(ThemeData lightTheme, ThemeData darkTheme) builder,
  }) {
    return builder(
      getLightTheme(),
      getDarkTheme(),
    );
  }
}
