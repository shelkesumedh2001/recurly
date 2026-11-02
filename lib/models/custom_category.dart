import 'package:hive/hive.dart';
import 'enums.dart';

part 'custom_category.g.dart';

/// User-created custom category
@HiveType(typeId: 7)
class CustomCategory extends HiveObject {
  CustomCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.isEmoji = true,
    this.colorHex,
    DateTime? createdAt,
    this.sortOrder = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Unique identifier
  @HiveField(0)
  String id;

  /// Category name
  @HiveField(1)
  String name;

  /// Icon - either emoji string or Material icon codepoint as string
  @HiveField(2)
  String icon;

  /// True for emoji, false for Material icon codepoint
  @HiveField(3)
  bool isEmoji;

  /// Optional color in hex format (e.g., '#F4A089')
  @HiveField(4)
  String? colorHex;

  /// When category was created
  @HiveField(5)
  DateTime createdAt;

  /// Sort order for display
  @HiveField(6)
  int sortOrder;

  /// Get display icon (handles both emoji and Material icons)
  String get displayIcon => icon;

  /// Create copy with updated fields
  CustomCategory copyWith({
    String? id,
    String? name,
    String? icon,
    bool? isEmoji,
    String? colorHex,
    DateTime? createdAt,
    int? sortOrder,
    bool clearColor = false,
  }) {
    return CustomCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isEmoji: isEmoji ?? this.isEmoji,
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  String toString() {
    return 'CustomCategory(id: $id, name: $name, icon: $icon, isEmoji: $isEmoji)';
  }
}

/// Unified category representation (combines enum + custom categories)
/// A category as the user sees it — built-in or their own. Used to file,
/// group, colour and label subscriptions (BUG-17).
class UnifiedCategory {
  const UnifiedCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.isCustom,
    this.isEmoji = true,
    this.colorHex,
    this.colorIndex = 0,
    this.builtIn,
  });

  /// Create from a built-in enum category
  factory UnifiedCategory.fromEnum(SubscriptionCategory enumCategory) {
    return UnifiedCategory(
      id: enumCategory.categoryName,
      name: enumCategory.displayName,
      icon: enumCategory.icon,
      isCustom: false,
      colorIndex: enumCategory.index,
      builtIn: enumCategory,
    );
  }

  /// Create from a custom category. [order] is its position among the
  /// custom categories; colours continue after the built-ins'.
  factory UnifiedCategory.fromCustom(CustomCategory custom, {int order = 0}) {
    return UnifiedCategory(
      id: custom.id,
      name: custom.name,
      icon: custom.icon,
      isCustom: true,
      isEmoji: custom.isEmoji,
      colorHex: custom.colorHex,
      colorIndex: SubscriptionCategory.values.length + order,
    );
  }

  final String id;
  final String name;

  /// Emoji, or a Material icon code point as a string when ![isEmoji].
  final String icon;
  final bool isCustom;
  final bool isEmoji;
  final String? colorHex;

  /// Index into the theme's chart palette: the enum index for built-ins,
  /// after them for custom categories. Stable across screens.
  final int colorIndex;

  /// The built-in category, or null for a custom one.
  final SubscriptionCategory? builtIn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedCategory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isCustom == other.isCustom;

  @override
  int get hashCode => id.hashCode ^ isCustom.hashCode;
}
