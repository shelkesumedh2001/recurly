import 'package:flutter/material.dart';

/// Theme preset definition
class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.backgroundColor,
    required this.cardColor,
    required this.accentColor,
    required this.expenseColor,
    required this.incomeColor,
    required this.warningColor,
    required this.textColor,
    required this.subtextColor,
    this.isSystem = false,
    this.isPremium = false,
  });

  final String id;
  final String name;
  final String description;
  final Brightness brightness;
  final Color backgroundColor;
  final Color cardColor;
  final Color accentColor;
  final Color expenseColor;
  final Color incomeColor;
  final Color warningColor;
  final Color textColor;
  final Color subtextColor;
  final bool isSystem;
  final bool isPremium;

  /// Get icon for this preset
  IconData get icon {
    switch (id) {
      case 'system':
        return Icons.brightness_auto;
      case 'light':
        return Icons.light_mode;
      case 'dark_warm':
        return Icons.local_fire_department;
      case 'dark_cool':
        return Icons.ac_unit;
      case 'amoled':
        return Icons.nights_stay;
      case 'sunset':
        return Icons.wb_twilight;
      case 'ocean':
        return Icons.water;
      case 'forest':
        return Icons.forest;
      default:
        return Icons.palette;
    }
  }
}

/// All available theme presets
class ThemePresets {
  // === SYSTEM THEME ===
  static const system = ThemePreset(
    id: 'system',
    name: 'System Default',
    description: 'Follow your device theme',
    brightness: Brightness.dark, // Placeholder - actual depends on system
    backgroundColor: Color(0xFF1A1514),
    cardColor: Color(0xFF2B2625),
    accentColor: Color(0xFFF4A089),
    expenseColor: Color(0xFFE74C3C),
    incomeColor: Color(0xFF48A868),
    warningColor: Color(0xFFFFB366),
    textColor: Color(0xFFF5F0EB),
    subtextColor: Color(0xFFABA6A3),
    isSystem: true,
  );

  // === LIGHT THEME ===
  static const light = ThemePreset(
    id: 'light',
    name: 'Light',
    description: 'Clean and bright',
    brightness: Brightness.light,
    backgroundColor: Color(0xFFFAF8F5),
    cardColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFFF4A089),
    expenseColor: Color(0xFFE74C3C),
    incomeColor: Color(0xFF48A868),
    warningColor: Color(0xFFFF9800),
    textColor: Color(0xFF1A1514),
    subtextColor: Color(0xFF6B6866),
  );

  // === DARK WARM (Current Default) ===
  static const darkWarm = ThemePreset(
    id: 'dark_warm',
    name: 'Dark Warm',
    description: 'Cozy brown tones',
    brightness: Brightness.dark,
    backgroundColor: Color(0xFF1A1514),
    cardColor: Color(0xFF2B2625),
    accentColor: Color(0xFFF4A089),
    expenseColor: Color(0xFFE74C3C),
    incomeColor: Color(0xFF48A868),
    warningColor: Color(0xFFFFB366),
    textColor: Color(0xFFF5F0EB),
    subtextColor: Color(0xFFABA6A3),
  );

  // === DARK COOL ===
  static const darkCool = ThemePreset(
    id: 'dark_cool',
    name: 'Dark Cool',
    description: 'Modern blue tones',
    brightness: Brightness.dark,
    backgroundColor: Color(0xFF12151A),
    cardColor: Color(0xFF1E2228),
    accentColor: Color(0xFF64B5F6),
    expenseColor: Color(0xFFEF5350),
    incomeColor: Color(0xFF66BB6A),
    warningColor: Color(0xFFFFB74D),
    textColor: Color(0xFFE8EAED),
    subtextColor: Color(0xFF9AA0A6),
  );

  // === AMOLED BLACK ===
  static const amoled = ThemePreset(
    id: 'amoled',
    name: 'AMOLED Black',
    description: 'Pure black for OLED',
    brightness: Brightness.dark,
    backgroundColor: Color(0xFF000000),
    cardColor: Color(0xFF121212),
    accentColor: Color(0xFFF4A089),
    expenseColor: Color(0xFFFF5252),
    incomeColor: Color(0xFF69F0AE),
    warningColor: Color(0xFFFFD740),
    textColor: Color(0xFFFFFFFF),
    subtextColor: Color(0xFFB3B3B3),
  );

  // === SUNSET ===
  static const sunset = ThemePreset(
    id: 'sunset',
    name: 'Sunset',
    description: 'Warm orange gradients',
    brightness: Brightness.dark,
    backgroundColor: Color(0xFF1A1210),
    cardColor: Color(0xFF2B201A),
    accentColor: Color(0xFFFF8A65),
    expenseColor: Color(0xFFFF5252),
    incomeColor: Color(0xFF81C784),
    warningColor: Color(0xFFFFCA28),
    textColor: Color(0xFFFFF3E0),
    subtextColor: Color(0xFFBCAAA4),
    isPremium: false,
  );

  // === OCEAN ===
  static const ocean = ThemePreset(
    id: 'ocean',
    name: 'Ocean',
    description: 'Deep sea blues',
    brightness: Brightness.dark,
    backgroundColor: Color(0xFF0D1B2A),
    cardColor: Color(0xFF1B2838),
    accentColor: Color(0xFF4DD0E1),
    expenseColor: Color(0xFFFF7043),
    incomeColor: Color(0xFF80CBC4),
    warningColor: Color(0xFFFFE082),
    textColor: Color(0xFFE0F7FA),
    subtextColor: Color(0xFF80DEEA),
    isPremium: false,
  );

  // === FOREST ===
  static const forest = ThemePreset(
    id: 'forest',
    name: 'Forest',
    description: 'Natural green tones',
    brightness: Brightness.dark,
    backgroundColor: Color(0xFF121A14),
    cardColor: Color(0xFF1E2920),
    accentColor: Color(0xFF81C784),
    expenseColor: Color(0xFFE57373),
    incomeColor: Color(0xFFA5D6A7),
    warningColor: Color(0xFFFFD54F),
    textColor: Color(0xFFE8F5E9),
    subtextColor: Color(0xFFA5D6A7),
    isPremium: false,
  );

  /// Get all available presets
  static List<ThemePreset> get all => [
    system,
    light,
    darkWarm,
    darkCool,
    amoled,
    sunset,
    ocean,
    forest,
  ];

  /// Get preset by ID
  static ThemePreset getById(String id) {
    return all.firstWhere(
      (preset) => preset.id == id,
      orElse: () => darkWarm,
    );
  }

  /// Get the effective preset for system theme
  static ThemePreset getSystemPreset(Brightness systemBrightness) {
    return systemBrightness == Brightness.dark ? darkWarm : light;
  }
}
