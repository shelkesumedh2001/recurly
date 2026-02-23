import 'package:flutter/material.dart';
import '../../theme/theme_presets.dart';

/// Preview card for a theme preset
class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
    this.customAccentColor,
  });

  final ThemePreset preset;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? customAccentColor;

  @override
  Widget build(BuildContext context) {
    final accentColor = customAccentColor ?? preset.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: preset.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : preset.cardColor,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview header with mock elements
              Row(
                children: [
                  // Mock card
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: preset.cardColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mock text lines
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: preset.textColor.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 4,
                          width: 40,
                          decoration: BoxDecoration(
                            color: preset.subtextColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Color dots preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildColorDot(accentColor),
                  _buildColorDot(preset.incomeColor),
                  _buildColorDot(preset.expenseColor),
                  _buildColorDot(preset.warningColor),
                ],
              ),

              const SizedBox(height: 12),

              // Theme name and icon
              Row(
                children: [
                  Icon(
                    preset.icon,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      preset.name,
                      style: TextStyle(
                        color: preset.textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: accentColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: preset.backgroundColor == color
              ? preset.textColor.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
    );
  }
}
