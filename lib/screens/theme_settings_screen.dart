import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_providers.dart';
import '../services/theme_service.dart';
import '../widgets/theme/color_picker_sheet.dart';
import '../widgets/theme/theme_preview_card.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preferences = ref.watch(themePreferencesProvider);
    final effectiveAccent = ref.watch(effectiveAccentColorProvider);
    final allPresets = ref.watch(availablePresetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Section: Theme Presets
          Text(
            'Choose Theme',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a theme that suits your style',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Theme grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: allPresets.length,
            itemBuilder: (context, index) {
              final preset = allPresets[index];
              final isSelected = preferences.themePresetId == preset.id;

              return ThemePreviewCard(
                preset: preset,
                isSelected: isSelected,
                onTap: () {
                  ref.read(themePreferencesProvider.notifier).setThemePreset(preset.id);
                },
                customAccentColor: isSelected ? ThemeService().parseHexColor(preferences.customAccentColorHex) : null,
              );
            },
          ),

          const SizedBox(height: 32),

          // Section: Accent Color
          Text(
            'Accent Color',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Customize the highlight color for buttons and interactive elements',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Current accent color card
          Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _showColorPicker(context, ref),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Color preview circle
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: effectiveAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: effectiveAccent.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preferences.customAccentColorHex != null
                                ? 'Custom Color'
                                : 'Theme Default',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getColorHex(effectiveAccent),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (preferences.customAccentColorHex != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  ref.read(themePreferencesProvider.notifier).setCustomAccentColor(null);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset to theme default'),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Section: Card Style
          Text(
            'Card Style',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how cards look throughout the app',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Gradient cards toggle
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Gradient Hero Cards'),
              subtitle: const Text('Use gradient backgrounds on summary cards'),
              value: preferences.useGradientCards,
              onChanged: (value) {
                ref.read(themePreferencesProvider.notifier).toggleGradientCards(value);
              },
            ),
          ),

          const SizedBox(height: 32),

          // Section: Reset
          Center(
            child: TextButton.icon(
              onPressed: () => _showResetDialog(context, ref),
              icon: const Icon(Icons.restore),
              label: const Text('Reset to Defaults'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    final preferences = ref.read(themePreferencesProvider);
    final themeService = ref.read(themeServiceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ColorPickerSheet(
        initialColor: themeService.parseHexColor(preferences.customAccentColorHex),
        onColorSelected: (color) {
          if (color != null) {
            final hex = themeService.colorToHex(color);
            ref.read(themePreferencesProvider.notifier).setCustomAccentColor(hex);
          } else {
            ref.read(themePreferencesProvider.notifier).setCustomAccentColor(null);
          }
        },
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Theme?'),
        content: const Text(
          'This will reset all theme settings to their defaults. Your data will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(themePreferencesProvider.notifier).resetToDefault();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme reset to defaults')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  String _getColorHex(Color color) {
    final r = color.r.toInt().toRadixString(16).padLeft(2, '0');
    final g = color.g.toInt().toRadixString(16).padLeft(2, '0');
    final b = color.b.toInt().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}
