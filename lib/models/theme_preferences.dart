import 'package:hive/hive.dart';

part 'theme_preferences.g.dart';

/// Theme customization preferences
@HiveType(typeId: 5)
class ThemePreferences extends HiveObject {
  ThemePreferences({
    this.themePresetId = 'system',
    this.customAccentColorHex,
    this.useGradientCards = true,
    this.cardStyle = 'default',
  });

  /// Theme preset identifier
  /// Options: 'system', 'light', 'dark_warm', 'dark_cool', 'amoled', 'sunset', 'ocean', 'forest'
  @HiveField(0)
  String themePresetId;

  /// Custom accent color in hex format (e.g., '#F4A089')
  /// If null, uses the preset's default accent color
  @HiveField(1)
  String? customAccentColorHex;

  /// Whether to use gradient backgrounds on hero cards
  @HiveField(2)
  bool useGradientCards;

  /// Card style: 'default', 'gradient', 'glass'
  @HiveField(3)
  String cardStyle;

  /// Create copy with updated fields
  ThemePreferences copyWith({
    String? themePresetId,
    String? customAccentColorHex,
    bool? useGradientCards,
    String? cardStyle,
    bool clearCustomAccent = false,
  }) {
    return ThemePreferences(
      themePresetId: themePresetId ?? this.themePresetId,
      customAccentColorHex: clearCustomAccent ? null : (customAccentColorHex ?? this.customAccentColorHex),
      useGradientCards: useGradientCards ?? this.useGradientCards,
      cardStyle: cardStyle ?? this.cardStyle,
    );
  }

  @override
  String toString() {
    return 'ThemePreferences(preset: $themePresetId, accent: $customAccentColorHex, gradient: $useGradientCards, cardStyle: $cardStyle)';
  }
}
