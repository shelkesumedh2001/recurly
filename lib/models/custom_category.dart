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
class UnifiedCategory {
  const UnifiedCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.isCustom,
    this.colorHex,
  });

  final String id;
  final String name;
  final String icon;
  final bool isCustom;
  final String? colorHex;

  /// Create from a built-in enum category
  factory UnifiedCategory.fromEnum(SubscriptionCategory enumCategory) {
    return UnifiedCategory(
      id: enumCategory.categoryName,
      name: enumCategory.displayName,
      icon: enumCategory.icon,
      isCustom: false,
    );
  }

  /// Create from a custom category
  factory UnifiedCategory.fromCustom(CustomCategory custom) {
    return UnifiedCategory(
      id: custom.id,
      name: custom.name,
      icon: custom.icon,
      isCustom: true,
      colorHex: custom.colorHex,
    );
  }

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
