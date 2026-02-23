import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/custom_category.dart';
import '../models/enums.dart';
import '../services/custom_category_service.dart';

/// Custom category service singleton provider
final customCategoryServiceProvider = Provider<CustomCategoryService>((ref) {
  return CustomCategoryService();
});

/// Custom categories state notifier
class CustomCategoryNotifier extends StateNotifier<List<CustomCategory>> {
  CustomCategoryNotifier(this._service) : super([]) {
    _loadCategories();
  }

  final CustomCategoryService _service;

  void _loadCategories() {
    state = _service.getAllCustomCategories();
  }

  /// Reload categories from storage
  void reload() {
    _loadCategories();
  }

  /// Add a new custom category
  Future<CustomCategory> addCategory({
    required String name,
    required String icon,
    bool isEmoji = true,
    String? colorHex,
  }) async {
    final category = await _service.addCategory(
      name: name,
      icon: icon,
      isEmoji: isEmoji,
      colorHex: colorHex,
    );
    _loadCategories();
    return category;
  }

  /// Update an existing category
  Future<void> updateCategory(CustomCategory category) async {
    await _service.updateCategory(category);
    _loadCategories();
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    await _service.deleteCategory(id);
    _loadCategories();
  }

  /// Reorder categories
  Future<void> reorderCategories(List<String> categoryIds) async {
    await _service.reorderCategories(categoryIds);
    _loadCategories();
  }
}

/// Custom categories provider
final customCategoriesProvider =
    StateNotifierProvider<CustomCategoryNotifier, List<CustomCategory>>((ref) {
  final service = ref.watch(customCategoryServiceProvider);
  return CustomCategoryNotifier(service);
});

/// All unified categories provider (enum + custom)
final allCategoriesProvider = Provider<List<UnifiedCategory>>((ref) {
  // Watch custom categories to trigger rebuild when they change
  ref.watch(customCategoriesProvider);
  final service = ref.read(customCategoryServiceProvider);
  return service.getAllUnifiedCategories();
});

/// Get unified category by ID provider (family)
final categoryByIdProvider =
    Provider.family<UnifiedCategory?, ({String id, bool isCustom})>((ref, params) {
  ref.watch(customCategoriesProvider);
  final service = ref.read(customCategoryServiceProvider);
  return service.getUnifiedCategoryById(params.id, isCustom: params.isCustom);
});

/// Check if category name exists provider
final categoryNameExistsProvider =
    Provider.family<bool, ({String name, String? excludeId})>((ref, params) {
  ref.watch(customCategoriesProvider);
  final service = ref.read(customCategoryServiceProvider);
  return service.categoryNameExists(params.name, excludeId: params.excludeId);
});

/// Custom categories count provider
final customCategoriesCountProvider = Provider<int>((ref) {
  return ref.watch(customCategoriesProvider).length;
});

/// Built-in categories provider (enum only)
final builtInCategoriesProvider = Provider<List<UnifiedCategory>>((ref) {
  return SubscriptionCategory.values
      .map((e) => UnifiedCategory.fromEnum(e))
      .toList();
});
