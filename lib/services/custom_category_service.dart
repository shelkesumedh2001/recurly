import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/custom_category.dart';
import '../models/enums.dart';
import '../utils/constants.dart';

/// Service for managing custom categories
class CustomCategoryService {
  CustomCategoryService._();
  static final CustomCategoryService _instance = CustomCategoryService._();
  factory CustomCategoryService() => _instance;

  Box<CustomCategory>? _categoryBox;
  final _uuid = const Uuid();

  /// Initialize the service
  Future<void> initialize() async {
    _categoryBox = await Hive.openBox<CustomCategory>(
      AppConstants.customCategoriesBox,
    );
  }

  /// Get all custom categories
  List<CustomCategory> getAllCustomCategories() {
    if (_categoryBox == null) return [];
    final categories = _categoryBox!.values.toList();
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  /// Get custom category by ID
  CustomCategory? getCategoryById(String id) {
    return _categoryBox?.get(id);
  }

  /// Add a new custom category
  Future<CustomCategory> addCategory({
    required String name,
    required String icon,
    bool isEmoji = true,
    String? colorHex,
  }) async {
    final category = CustomCategory(
      id: _uuid.v4(),
      name: name,
      icon: icon,
      isEmoji: isEmoji,
      colorHex: colorHex,
      sortOrder: getAllCustomCategories().length,
    );

    await _categoryBox?.put(category.id, category);
    return category;
  }

  /// Update an existing category
  Future<void> updateCategory(CustomCategory category) async {
    await _categoryBox?.put(category.id, category);
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    await _categoryBox?.delete(id);
  }

  /// Reorder categories
  Future<void> reorderCategories(List<String> categoryIds) async {
    for (int i = 0; i < categoryIds.length; i++) {
      final category = getCategoryById(categoryIds[i]);
      if (category != null) {
        await updateCategory(category.copyWith(sortOrder: i));
      }
    }
  }

  /// Get all unified categories (enum + custom)
  List<UnifiedCategory> getAllUnifiedCategories() {
    final List<UnifiedCategory> unified = [];

    // Add built-in categories first
    for (final enumCategory in SubscriptionCategory.values) {
      unified.add(UnifiedCategory.fromEnum(enumCategory));
    }

    // Add custom categories
    for (final custom in getAllCustomCategories()) {
      unified.add(UnifiedCategory.fromCustom(custom));
    }

    return unified;
  }

  /// Get unified category by ID
  UnifiedCategory? getUnifiedCategoryById(String id, {bool isCustom = false}) {
    if (isCustom) {
      final custom = getCategoryById(id);
      if (custom != null) {
        return UnifiedCategory.fromCustom(custom);
      }
    } else {
      // Try to match enum category
      try {
        final enumCategory = SubscriptionCategory.values.firstWhere(
          (e) => e.categoryName == id,
        );
        return UnifiedCategory.fromEnum(enumCategory);
      } catch (_) {
        // Not found
      }
    }
    return null;
  }

  /// Check if a category name already exists
  bool categoryNameExists(String name, {String? excludeId}) {
    // Check built-in categories
    for (final enumCategory in SubscriptionCategory.values) {
      if (enumCategory.displayName.toLowerCase() == name.toLowerCase()) {
        return true;
      }
    }

    // Check custom categories
    for (final custom in getAllCustomCategories()) {
      if (custom.name.toLowerCase() == name.toLowerCase() &&
          custom.id != excludeId) {
        return true;
      }
    }

    return false;
  }

  /// Watch for changes
  Stream<BoxEvent>? watchCategories() {
    return _categoryBox?.watch();
  }

  /// Close the service
  Future<void> close() async {
    await _categoryBox?.close();
  }
}
