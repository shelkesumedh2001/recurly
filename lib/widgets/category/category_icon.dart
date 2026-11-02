import 'package:flutter/material.dart';

import '../../models/custom_category.dart';

/// A category's icon: its emoji, or the Material icon a custom category
/// was given (stored as a code point string).
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key, this.size = 24, this.color});

  final UnifiedCategory category;
  final double size;

  /// Tint for Material icons (emoji keep their own colours).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!category.isEmoji) {
      final codePoint = int.tryParse(category.icon);
      if (codePoint != null) {
        return Icon(
          IconData(codePoint, fontFamily: 'MaterialIcons'),
          size: size,
          color: color,
        );
      }
    }
    return Text(category.icon, style: TextStyle(fontSize: size));
  }
}
