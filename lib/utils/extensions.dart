import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Extension methods for DateTime
extension DateTimeExtensions on DateTime {
  /// Format as "MMM dd, yyyy" (e.g., "Jan 15, 2024")
  String toFormattedDate() {
    return DateFormat('MMM dd, yyyy').format(this);
  }

  /// Format as "MMM dd" (e.g., "Jan 15")
  String toShortDate() {
    return DateFormat('MMM dd').format(this);
  }

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  /// Get days between this date and now
  int get daysFromNow {
    final now = DateTime.now();
    final diff = this.difference(now);
    return diff.inDays;
  }
}

/// Extension methods for BuildContext
extension ContextExtensions on BuildContext {
  /// Get theme
  ThemeData get theme => Theme.of(this);

  /// Get color scheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Get text theme
  TextTheme get textTheme => theme.textTheme;

  /// Get media query
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Get screen size
  Size get screenSize => mediaQuery.size;

  /// Get screen width
  double get screenWidth => screenSize.width;

  /// Get screen height
  double get screenHeight => screenSize.height;

  /// Show snackbar
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Extension methods for String
extension StringExtensions on String {
  /// Capitalize first letter
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Check if string is a valid number
  bool get isNumeric {
    return double.tryParse(this) != null;
  }
}

/// Extension methods for double
extension DoubleExtensions on double {
  /// Format as currency
  String toCurrency({String symbol = '\$'}) {
    return '$symbol${toStringAsFixed(2)}';
  }

  /// Format with commas for thousands
  String toFormattedString() {
    final formatter = NumberFormat('#,##0.00');
    return formatter.format(this);
  }
}
