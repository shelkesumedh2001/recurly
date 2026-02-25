import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/theme_preferences.dart';
import '../theme/theme_presets.dart';
import '../utils/constants.dart';

/// Service for managing theme preferences and generating themes
class ThemeService {
  ThemeService._();
  static final ThemeService _instance = ThemeService._();
  factory ThemeService() => _instance;

  Box<ThemePreferences>? _themeBox;
  static const String _preferencesKey = 'theme_preferences';

  /// Initialize the theme service
  Future<void> initialize() async {
    _themeBox = await Hive.openBox<ThemePreferences>(
      AppConstants.themePreferencesBox,
    );
  }

  /// Get current theme preferences
  ThemePreferences getPreferences() {
    return _themeBox?.get(_preferencesKey) ?? ThemePreferences();
  }

  /// Save theme preferences
  Future<void> savePreferences(ThemePreferences preferences) async {
    await _themeBox?.put(_preferencesKey, preferences);
  }

  /// Watch for preference changes
  Stream<BoxEvent>? watchPreferences() {
    return _themeBox?.watch(key: _preferencesKey);
  }

  /// Get the current theme mode
  ThemeMode getThemeMode(ThemePreferences preferences) {
    switch (preferences.themePresetId) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.dark;
    }
  }

  /// Get the effective preset based on preferences and system brightness
  ThemePreset getEffectivePreset(ThemePreferences preferences, Brightness systemBrightness) {
    if (preferences.themePresetId == 'system') {
      return ThemePresets.getSystemPreset(systemBrightness);
    }
    return ThemePresets.getById(preferences.themePresetId);
  }

  /// Parse hex color string to Color
  Color? parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length != 6) return null;
    try {
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (e) {
      return null;
    }
  }

  /// Convert Color to hex string
  String colorToHex(Color color) {
    final r = color.r.toInt().toRadixString(16).padLeft(2, '0');
    final g = color.g.toInt().toRadixString(16).padLeft(2, '0');
    final b = color.b.toInt().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  /// Generate light theme from preset
  ThemeData generateLightTheme(ThemePreferences preferences) {
    final preset = preferences.themePresetId == 'system'
        ? ThemePresets.light
        : ThemePresets.getById(preferences.themePresetId);

    final effectivePreset = preset.brightness == Brightness.light
        ? preset
        : ThemePresets.light;

    return _buildTheme(effectivePreset, preferences, Brightness.light);
  }

  /// Generate dark theme from preset
  ThemeData generateDarkTheme(ThemePreferences preferences) {
    final preset = preferences.themePresetId == 'system'
        ? ThemePresets.darkWarm
        : ThemePresets.getById(preferences.themePresetId);

    final effectivePreset = preset.brightness == Brightness.dark
        ? preset
        : ThemePresets.darkWarm;

    return _buildTheme(effectivePreset, preferences, Brightness.dark);
  }

  /// Build theme from preset and preferences
  ThemeData _buildTheme(
    ThemePreset preset,
    ThemePreferences preferences,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;

    // Use custom accent color if provided, otherwise use preset's accent
    final accentColor = parseHexColor(preferences.customAccentColorHex) ?? preset.accentColor;

    final colorScheme = isDark
        ? _buildDarkColorScheme(preset, accentColor)
        : _buildLightColorScheme(preset, accentColor);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: preset.backgroundColor,
      brightness: brightness,

      // Typography
      textTheme: _buildTextTheme(colorScheme, preset),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? preset.cardColor.withValues(alpha: 0.5)
                : colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        color: preset.cardColor,
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing8,
        ),
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 4,
        backgroundColor: accentColor,
        foregroundColor: isDark ? preset.backgroundColor : Colors.white,
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: preset.cardColor,
        modalBackgroundColor: preset.cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: preset.subtextColor.withValues(alpha: 0.3),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? preset.cardColor.withValues(alpha: 0.7)
            : colorScheme.surfaceContainer,
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
            color: accentColor.withValues(alpha: 0.8),
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
        backgroundColor: preset.backgroundColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: preset.textColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: preset.textColor),
      ),

      // Navigation bar theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: preset.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: accentColor.withValues(alpha: 0.2),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: preset.subtextColor,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accentColor, size: 24);
          }
          return IconThemeData(color: preset.subtextColor, size: 24);
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
            return accentColor;
          }
          return preset.subtextColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentColor.withValues(alpha: 0.3);
          }
          return preset.subtextColor.withValues(alpha: 0.2);
        }),
      ),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  ColorScheme _buildDarkColorScheme(ThemePreset preset, Color accentColor) {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: accentColor,
      onPrimary: preset.backgroundColor,
      primaryContainer: accentColor.withValues(alpha: 0.2),
      onPrimaryContainer: accentColor,
      secondary: preset.incomeColor,
      onSecondary: Colors.white,
      secondaryContainer: preset.incomeColor.withValues(alpha: 0.2),
      onSecondaryContainer: preset.incomeColor,
      tertiary: preset.warningColor,
      onTertiary: preset.backgroundColor,
      tertiaryContainer: preset.warningColor.withValues(alpha: 0.2),
      onTertiaryContainer: preset.warningColor,
      error: preset.expenseColor,
      onError: Colors.white,
      errorContainer: preset.expenseColor.withValues(alpha: 0.2),
      onErrorContainer: preset.expenseColor,
      surface: preset.backgroundColor,
      onSurface: preset.textColor,
      surfaceContainerHighest: preset.cardColor.withValues(alpha: 0.8),
      surfaceContainerHigh: preset.cardColor,
      surfaceContainer: preset.cardColor,
      surfaceContainerLow: preset.backgroundColor,
      surfaceContainerLowest: preset.backgroundColor,
      outline: preset.subtextColor,
      outlineVariant: preset.cardColor,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: preset.textColor,
      onInverseSurface: preset.backgroundColor,
      inversePrimary: accentColor,
    );
  }

  ColorScheme _buildLightColorScheme(ThemePreset preset, Color accentColor) {
    return ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
      surface: preset.backgroundColor,
      surfaceContainer: preset.cardColor,
      primary: accentColor,
      secondary: preset.incomeColor,
      tertiary: preset.warningColor,
      error: preset.expenseColor,
    );
  }

  TextTheme _buildTextTheme(ColorScheme colorScheme, ThemePreset preset) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
        color: preset.textColor,
      ),
      displayMedium: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: preset.textColor,
      ),
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: preset.textColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: preset.textColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: preset.textColor,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: preset.textColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: preset.textColor,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: preset.textColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
        color: preset.textColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
        color: preset.textColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.2,
        color: preset.subtextColor,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: preset.textColor,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: preset.subtextColor,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: preset.subtextColor,
      ),
    );
  }

  /// Close the service
  Future<void> close() async {
    await _themeBox?.close();
  }
}
