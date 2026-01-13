import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Material 3 theme configuration - "Dark Warm Brown"
/// Inspired by sleek finance apps with warm dark tones
class AppTheme {
  // === PRIMARY COLOR PALETTE ===
  // Deep warm brown/black background
  static const _darkBg = Color(0xFF1A1514);
  static const _darkSurface = Color(0xFF1A1514);
  static const _darkCard = Color(0xFF2B2625);
  static const _darkCardHighlight = Color(0xFF3D3635);

  // Light theme colors (warm cream tones)
  static const _lightBg = Color(0xFFFAF8F5);
  static const _lightCard = Color(0xFFFFFFFF);

  // Accent Colors
  static const _primaryCoral = Color(0xFFF4A089); // Peach/coral for FAB
  static const _expenseRed = Color(0xFFE74C3C); // Red for expenses
  static const _incomeGreen = Color(0xFF48A868); // Green for income/positive
  static const _warningAmber = Color(0xFFFFB366); // Amber for warnings

  /// Get the light theme
  static ThemeData getLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryCoral,
      brightness: Brightness.light,
      surface: _lightBg,
      surfaceContainer: _lightCard,
      primary: _primaryCoral,
      secondary: _incomeGreen,
      tertiary: _warningAmber,
      error: _expenseRed,
    );

    return _buildBaseTheme(colorScheme, Brightness.light);
  }

  /// Get the dark theme
  static ThemeData getDarkTheme() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      // Primary colors
      primary: _primaryCoral,
      onPrimary: const Color(0xFF1A1514),
      primaryContainer: _primaryCoral.withValues(alpha: 0.2),
      onPrimaryContainer: _primaryCoral,
      // Secondary colors
      secondary: _incomeGreen,
      onSecondary: Colors.white,
      secondaryContainer: _incomeGreen.withValues(alpha: 0.2),
      onSecondaryContainer: _incomeGreen,
      // Tertiary colors
      tertiary: _warningAmber,
      onTertiary: const Color(0xFF1A1514),
      tertiaryContainer: _warningAmber.withValues(alpha: 0.2),
      onTertiaryContainer: _warningAmber,
      // Error colors
      error: _expenseRed,
      onError: Colors.white,
      errorContainer: _expenseRed.withValues(alpha: 0.2),
      onErrorContainer: _expenseRed,
      // Surface colors
      surface: _darkSurface,
      onSurface: const Color(0xFFF5F0EB),
      surfaceContainerHighest: _darkCardHighlight,
      surfaceContainerHigh: _darkCard,
      surfaceContainer: _darkCard,
      surfaceContainerLow: const Color(0xFF252120),
      surfaceContainerLowest: _darkBg,
      // Other
      outline: const Color(0xFF5A5250),
      outlineVariant: const Color(0xFF3D3635),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFF5F0EB),
      onInverseSurface: const Color(0xFF1A1514),
      inversePrimary: const Color(0xFFB87A65),
    );

    return _buildBaseTheme(colorScheme, Brightness.dark);
  }

  /// Base theme builder
  static ThemeData _buildBaseTheme(ColorScheme colorScheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      brightness: brightness,

      // Typography
      textTheme: _getTextTheme(colorScheme),

      // Card theme - Warm, rounded with subtle borders
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF3D3635)
                : colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        color: isDark ? _darkCard : _lightCard,
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing8,
        ),
      ),

      // FAB theme - Coral accent
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 4,
        backgroundColor: _primaryCoral,
        foregroundColor: isDark ? const Color(0xFF1A1514) : Colors.white,
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? _darkCard : _lightCard,
        modalBackgroundColor: isDark ? _darkCard : _lightCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurface.withValues(alpha: 0.3),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkCardHighlight : colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: _primaryCoral.withValues(alpha: 0.8),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),

      // App bar theme
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      // Navigation bar theme (bottom nav)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? _darkBg : _lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: _primaryCoral.withValues(alpha: 0.2),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _primaryCoral,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: _primaryCoral, size: 24);
          }
          return IconThemeData(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            size: 24,
          );
        }),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing20,
          vertical: 4,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: Colors.transparent,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.1),
        thickness: 1,
        space: 1,
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryCoral;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryCoral.withValues(alpha: 0.3);
          }
          return colorScheme.outline.withValues(alpha: 0.2);
        }),
      ),

      // Animation durations
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Clean, readable text theme
  static TextTheme _getTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      // Large display numbers (for hero amounts)
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: colorScheme.onSurface,
      ),
      // Screen titles
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: colorScheme.onSurface,
      ),
      // Card titles
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      // Body text
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.2,
        color: colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      // Labels
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  /// Get color for renewal urgency
  static Color getRenewalUrgencyColor(
    BuildContext context,
    int daysUntilRenewal,
  ) {
    if (daysUntilRenewal < AppConstants.renewalUrgentThreshold) {
      return _expenseRed;
    } else if (daysUntilRenewal < AppConstants.renewalWarningThreshold) {
      return _warningAmber;
    } else {
      return _incomeGreen;
    }
  }

  /// Vibrant chart colors (matching the inspiration)
  static const List<Color> _chartColors = [
    Color(0xFFE74C3C), // Red
    Color(0xFF9B59B6), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFFFF9800), // Orange
    Color(0xFF48A868), // Green
  ];

  /// Get chart colors
  static List<Color> getChartColors(BuildContext context) {
    return _chartColors;
  }

  /// Get category color for charts
  static Color getCategoryColor(int index) {
    return _chartColors[index % _chartColors.length];
  }

  /// Get gradient for category (for sleek effects)
  static List<Color> getCategoryGradient(int index) {
    final baseColor = getCategoryColor(index);
    return [
      baseColor,
      HSLColor.fromColor(baseColor).withLightness(
        (HSLColor.fromColor(baseColor).lightness - 0.15).clamp(0.0, 1.0),
      ).toColor(),
    ];
  }

  /// Get expense color (red)
  static Color get expenseColor => _expenseRed;

  /// Get income color (green)
  static Color get incomeColor => _incomeGreen;

  /// Get primary coral color
  static Color get primaryCoral => _primaryCoral;

  /// Calendar heatmap colors (light to dark based on activity)
  static List<Color> getCalendarHeatmapColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        const Color(0xFF2B2625), // No activity (card background)
        const Color(0xFF5D3A3A), // Low
        const Color(0xFF8B4545), // Medium
        const Color(0xFFB84C4C), // High
        const Color(0xFFE74C3C), // Very high (expense red)
      ];
    } else {
      return [
        const Color(0xFFF5F0EB),
        const Color(0xFFFFCDD2),
        const Color(0xFFEF9A9A),
        const Color(0xFFE57373),
        const Color(0xFFE74C3C),
      ];
    }
  }

  /// Create theme wrapper
  static Widget buildWithTheme({
    required Widget Function(ThemeData lightTheme, ThemeData darkTheme) builder,
  }) {
    return builder(
      getLightTheme(),
      getDarkTheme(),
    );
  }
}
