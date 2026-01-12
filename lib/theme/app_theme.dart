import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Material 3 theme configuration - "Warm Modern"
/// Inspired by clean, earthy expense tracking apps with warm tones
class AppTheme {
  // Warm, Modern Color Palette
  static const _seedColor = Color(0xFFF4A89B); // Soft peach/coral

  // Base Colors
  static const _lightBg = Color(0xFFFAFAFA); // Soft off-white
  static const _darkBg = Color(0xFF1C1B1B); // Warm dark gray (not pure black)

  /// Get the light theme
  static ThemeData getLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      surface: _lightBg,
      surfaceContainer: const Color(0xFFF5F3F0), // Warm light gray for cards
      primary: const Color(0xFFF4A89B), // Peach/coral
      secondary: const Color(0xFF8B9B7E), // Muted olive/sage
      tertiary: const Color(0xFFB8886B), // Warm brown
    );

    return _buildBaseTheme(colorScheme);
  }

  /// Get the dark theme
  static ThemeData getDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      surface: _darkBg,
      surfaceContainer: const Color(0xFF2B2928), // Warm gray for cards
      primary: const Color(0xFFF4A89B), // Peach/coral
      secondary: const Color(0xFF8B9B7E), // Muted olive/sage
      tertiary: const Color(0xFFB8886B), // Warm brown
      // Softer error color for dark mode
      error: const Color(0xFFFF6B6B),
    );

    return _buildBaseTheme(colorScheme);
  }

  /// Base theme builder
  static ThemeData _buildBaseTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // Typography (Clean & readable)
      textTheme: _getTextTheme(),

      // Card theme (Warm, flat design with subtle borders)
      cardTheme: CardTheme(
        elevation: 0, // Flat design - no shadows
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // Large rounded corners
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.06), // Very subtle border
            width: 1,
          ),
        ),
        color: colorScheme.surfaceContainer,
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing24,
          vertical: AppConstants.spacing8,
        ),
      ),

      // FAB theme (Soft peach, warm and inviting)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 2, // Subtle elevation
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        modalBackgroundColor: colorScheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        showDragHandle: true,
      ),

      // Input decoration theme (Soft, rounded)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),
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
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
          fontSize: 24, // Larger title
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing24,
          vertical: 4,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Animation durations
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Clean, readable text theme with good hierarchy
  static TextTheme _getTextTheme() {
    return const TextTheme(
      // Large display numbers (for hero amounts)
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
      ),
      // Screen titles
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      // Card titles
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      // Subtitle text
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      // Body text
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
      ),
      // Secondary text
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
      ),
    );
  }

  /// Get color for renewal urgency (Soft, warm colors)
  static Color getRenewalUrgencyColor(
    BuildContext context,
    int daysUntilRenewal,
  ) {
    if (daysUntilRenewal < AppConstants.renewalUrgentThreshold) {
      return const Color(0xFFFF6B6B); // Soft red/coral
    } else if (daysUntilRenewal < AppConstants.renewalWarningThreshold) {
      return const Color(0xFFFFB366); // Warm amber
    } else {
      return const Color(0xFF69CBA0); // Soft mint green
    }
  }

  /// Chart colors for analytics (warm, muted palette)
  static List<Color> getChartColors(BuildContext context) {
    return const [
      Color(0xFFF4A89B), // Peach (Entertainment)
      Color(0xFF8B9B7E), // Sage (Utilities)
      Color(0xFFB8886B), // Brown (Health)
      Color(0xFF69CBA0), // Mint (Finance)
      Color(0xFFFFB366), // Amber (Productivity)
      Color(0xFFB8B8B8), // Gray (Other)
    ];
  }

  /// Get category color for charts - Vibrant, sleek palette
  static Color getCategoryColor(int index) {
    const colors = [
      Color(0xFFE63946), // Vibrant Red
      Color(0xFF457B9D), // Deep Blue
      Color(0xFF9D4EDD), // Rich Purple
      Color(0xFF06FFA5), // Electric Mint
      Color(0xFFFFB703), // Bold Amber
      Color(0xFFFF006E), // Hot Pink
    ];
    return colors[index % colors.length];
  }

  /// Get gradient for category (for sleek effects)
  static List<Color> getCategoryGradient(int index) {
    const gradients = [
      [Color(0xFFE63946), Color(0xFFD62828)], // Red gradient
      [Color(0xFF457B9D), Color(0xFF1D3557)], // Blue gradient
      [Color(0xFF9D4EDD), Color(0xFF7209B7)], // Purple gradient
      [Color(0xFF06FFA5), Color(0xFF00D9A3)], // Mint gradient
      [Color(0xFFFFB703), Color(0xFFFB8500)], // Amber gradient
      [Color(0xFFFF006E), Color(0xFFC9184A)], // Pink gradient
    ];
    return gradients[index % gradients.length];
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
