import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/theme_preferences.dart';
import '../services/theme_service.dart';
import '../theme/theme_presets.dart';

/// Theme service singleton provider
final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

/// Theme preferences state notifier
class ThemeNotifier extends StateNotifier<ThemePreferences> {
  ThemeNotifier(this._themeService) : super(ThemePreferences()) {
    _loadPreferences();
  }

  final ThemeService _themeService;

  void _loadPreferences() {
    state = _themeService.getPreferences();
  }

  /// Update the entire theme preferences
  Future<void> updatePreferences(ThemePreferences preferences) async {
    await _themeService.savePreferences(preferences);
    state = preferences;
  }

  /// Set the theme preset
  Future<void> setThemePreset(String presetId) async {
    final updated = state.copyWith(themePresetId: presetId);
    await updatePreferences(updated);
  }

  /// Set custom accent color
  Future<void> setCustomAccentColor(String? hexColor) async {
    final updated = state.copyWith(
      customAccentColorHex: hexColor,
      clearCustomAccent: hexColor == null,
    );
    await updatePreferences(updated);
  }

  /// Toggle gradient cards
  Future<void> toggleGradientCards(bool enabled) async {
    final updated = state.copyWith(useGradientCards: enabled);
    await updatePreferences(updated);
  }

  /// Set card style
  Future<void> setCardStyle(String style) async {
    final updated = state.copyWith(cardStyle: style);
    await updatePreferences(updated);
  }

  /// Reset to default theme
  Future<void> resetToDefault() async {
    await updatePreferences(ThemePreferences());
  }
}

/// Main theme preferences provider
final themePreferencesProvider = StateNotifierProvider<ThemeNotifier, ThemePreferences>((ref) {
  final themeService = ref.watch(themeServiceProvider);
  return ThemeNotifier(themeService);
});

/// Current theme mode provider
final themeModeProvider = Provider<ThemeMode>((ref) {
  final preferences = ref.watch(themePreferencesProvider);
  final themeService = ref.read(themeServiceProvider);
  return themeService.getThemeMode(preferences);
});

/// Current theme preset provider
final currentPresetProvider = Provider<ThemePreset>((ref) {
  final preferences = ref.watch(themePreferencesProvider);
  return ThemePresets.getById(preferences.themePresetId);
});

/// Light theme data provider
final lightThemeProvider = Provider<ThemeData>((ref) {
  final preferences = ref.watch(themePreferencesProvider);
  final themeService = ref.read(themeServiceProvider);
  return themeService.generateLightTheme(preferences);
});

/// Dark theme data provider
final darkThemeProvider = Provider<ThemeData>((ref) {
  final preferences = ref.watch(themePreferencesProvider);
  final themeService = ref.read(themeServiceProvider);
  return themeService.generateDarkTheme(preferences);
});

/// Effective accent color provider (respects custom accent)
final effectiveAccentColorProvider = Provider<Color>((ref) {
  final preferences = ref.watch(themePreferencesProvider);
  final themeService = ref.read(themeServiceProvider);
  final preset = ThemePresets.getById(preferences.themePresetId);

  return themeService.parseHexColor(preferences.customAccentColorHex) ?? preset.accentColor;
});

/// All available presets provider
final availablePresetsProvider = Provider<List<ThemePreset>>((ref) {
  return ThemePresets.all;
});

/// Check if current theme is dark
final isDarkThemeProvider = Provider<bool>((ref) {
  final preset = ref.watch(currentPresetProvider);
  return preset.brightness == Brightness.dark;
});
