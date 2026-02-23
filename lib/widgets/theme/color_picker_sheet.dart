import 'package:flutter/material.dart';

/// Bottom sheet for picking custom accent color
class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({
    super.key,
    this.initialColor,
    required this.onColorSelected,
  });

  final Color? initialColor;
  final void Function(Color?) onColorSelected;

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  Color? _selectedColor;

  // Predefined accent colors
  static const List<Color> _presetColors = [
    Color(0xFFF4A089), // Coral (default)
    Color(0xFFFF6B6B), // Red
    Color(0xFFFF8C42), // Orange
    Color(0xFFFFD93D), // Yellow
    Color(0xFF6BCB77), // Green
    Color(0xFF4ECDC4), // Teal
    Color(0xFF64B5F6), // Blue
    Color(0xFF7B68EE), // Purple
    Color(0xFFE040FB), // Pink/Magenta
    Color(0xFFFF4081), // Hot Pink
    Color(0xFFB388FF), // Light Purple
    Color(0xFF18FFFF), // Cyan
    Color(0xFF69F0AE), // Light Green
    Color(0xFFFFAB40), // Amber
    Color(0xFFFF6E40), // Deep Orange
    Color(0xFFE91E63), // Rose
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accent Color',
                style: theme.textTheme.headlineSmall,
              ),
              if (_selectedColor != null)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedColor = null);
                  },
                  child: const Text('Reset'),
                ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            'Choose a custom accent color for buttons and highlights',
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 24),

          // Color grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _presetColors.length,
            itemBuilder: (context, index) {
              final color = _presetColors[index];
              final isSelected = _selectedColor?.value == color.value;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedColor = color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: _getContrastColor(color),
                        )
                      : null,
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Preview FAB
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _selectedColor ?? theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.add,
                    color: _getContrastColor(
                      _selectedColor ?? theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedColor != null
                            ? 'Custom accent color'
                            : 'Using theme default',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _selectedColor ?? theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                  onPressed: () {
                    widget.onColorSelected(_selectedColor);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
