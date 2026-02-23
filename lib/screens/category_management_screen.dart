import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/custom_category.dart';
import '../models/enums.dart';
import '../providers/category_providers.dart';
import '../widgets/category/icon_picker_sheet.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customCategories = ref.watch(customCategoriesProvider);
    final builtInCategories = ref.watch(builtInCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategorySheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Built-in categories section
          Text(
            'Built-in Categories',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These categories cannot be modified',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          ...builtInCategories.map((category) => _buildBuiltInCategoryCard(
                context,
                category,
              )),

          const SizedBox(height: 32),

          // Custom categories section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Categories',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${customCategories.length} custom ${customCategories.length == 1 ? 'category' : 'categories'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (customCategories.isEmpty)
            _buildEmptyState(context)
          else
            ...customCategories.map((category) => _buildCustomCategoryCard(
                  context,
                  ref,
                  category,
                )),

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildBuiltInCategoryCard(BuildContext context, UnifiedCategory category) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              category.icon,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Built-in'),
        trailing: Icon(
          Icons.lock_outline,
          size: 18,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildCustomCategoryCard(
    BuildContext context,
    WidgetRef ref,
    CustomCategory category,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: category.colorHex != null
                ? _parseColor(category.colorHex!).withValues(alpha: 0.2)
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: category.isEmoji
                ? Text(
                    category.icon,
                    style: const TextStyle(fontSize: 22),
                  )
                : Icon(
                    IconData(
                      int.tryParse(category.icon) ?? 0,
                      fontFamily: 'MaterialIcons',
                    ),
                    size: 24,
                    color: category.colorHex != null
                        ? _parseColor(category.colorHex!)
                        : theme.colorScheme.onPrimaryContainer,
                  ),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Custom'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEditCategorySheet(context, ref, category),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              onPressed: () => _showDeleteDialog(context, ref, category),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No custom categories yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first custom category',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context, WidgetRef ref) {
    _showCategorySheet(
      context,
      ref,
      title: 'New Category',
      onSave: (name, icon, isEmoji, colorHex) async {
        await ref.read(customCategoriesProvider.notifier).addCategory(
              name: name,
              icon: icon,
              isEmoji: isEmoji,
              colorHex: colorHex,
            );
      },
    );
  }

  void _showEditCategorySheet(
    BuildContext context,
    WidgetRef ref,
    CustomCategory category,
  ) {
    _showCategorySheet(
      context,
      ref,
      title: 'Edit Category',
      initialName: category.name,
      initialIcon: category.icon,
      initialIsEmoji: category.isEmoji,
      initialColorHex: category.colorHex,
      excludeId: category.id,
      onSave: (name, icon, isEmoji, colorHex) async {
        await ref.read(customCategoriesProvider.notifier).updateCategory(
              category.copyWith(
                name: name,
                icon: icon,
                isEmoji: isEmoji,
                colorHex: colorHex,
              ),
            );
      },
    );
  }

  void _showCategorySheet(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    String? initialName,
    String? initialIcon,
    bool initialIsEmoji = true,
    String? initialColorHex,
    String? excludeId,
    required Future<void> Function(String name, String icon, bool isEmoji, String? colorHex) onSave,
  }) {
    final nameController = TextEditingController(text: initialName);
    String selectedIcon = initialIcon ?? '';
    bool isEmoji = initialIsEmoji;
    String? colorHex = initialColorHex;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),

                  // Icon picker button
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => IconPickerSheet(
                              initialIcon: selectedIcon.isNotEmpty ? selectedIcon : null,
                              initialIsEmoji: isEmoji,
                              onIconSelected: (icon, emoji) {
                                setState(() {
                                  selectedIcon = icon;
                                  isEmoji = emoji;
                                });
                              },
                            ),
                          );
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colorHex != null
                                ? _parseColor(colorHex!).withValues(alpha: 0.2)
                                : theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: selectedIcon.isEmpty
                              ? Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: theme.colorScheme.outline,
                                )
                              : Center(
                                  child: isEmoji
                                      ? Text(
                                          selectedIcon,
                                          style: const TextStyle(fontSize: 32),
                                        )
                                      : Icon(
                                          IconData(
                                            int.tryParse(selectedIcon) ?? 0,
                                            fontFamily: 'MaterialIcons',
                                          ),
                                          size: 32,
                                        ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Icon',
                              style: theme.textTheme.labelMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedIcon.isEmpty
                                  ? 'Tap to choose an icon'
                                  : 'Tap to change',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Name field
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g., Gaming, Travel',
                    ),
                    textCapitalization: TextCapitalization.words,
                    autofocus: initialName == null,
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a name')),
                              );
                              return;
                            }
                            if (selectedIcon.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select an icon')),
                              );
                              return;
                            }

                            // Check for duplicate name
                            final service = ref.read(customCategoryServiceProvider);
                            if (service.categoryNameExists(name, excludeId: excludeId)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('A category with this name already exists')),
                              );
                              return;
                            }

                            await onSave(name, selectedIcon, isEmoji, colorHex);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    CustomCategory category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text(
          'Subscriptions using this category will be moved to "Other".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(customCategoriesProvider.notifier)
                  .deleteCategory(category.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${category.name}" deleted')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleanHex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleanHex', radix: 16));
  }
}
