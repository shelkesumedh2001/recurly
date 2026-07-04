import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'theme_presets.dart';

/// Corner radius scale. Matches the app's established shape language
/// (cards 20, floating sheets 24, modal sheets 28) so new code and old
/// code agree on the same values.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double sheet = 28;
}

/// Motion tokens: durations and curves for the whole app.
///
/// Always wrap durations in [AppMotion.of] so animations collapse to zero
/// when the user has reduced motion enabled at the OS level.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Respect the OS reduced-motion setting.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
}

/// Tabular figures for money and dates so digit columns align in lists.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

/// Soft accent glow — the app's emphasis/selection signature (originally
/// from the theme picker's selected card). Use sparingly: the hero, the
/// FAB, and small selected controls.
List<BoxShadow> appGlow(
  Color color, {
  double alpha = 0.3,
  double blur = 12,
  double spread = 1,
}) =>
    [
      BoxShadow(
        color: color.withValues(alpha: alpha),
        blurRadius: blur,
        spreadRadius: spread,
      ),
    ];

/// Semantic, preset-aware design tokens.
///
/// This is the single source of truth for colors that carry meaning
/// (spend up/down, renewal urgency, charts). Widgets read it via
/// `AppTokens.of(context)` so every theme preset — and the custom accent —
/// colors the whole app, not just the Material color scheme.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.success,
    required this.warning,
    required this.danger,
    required this.chartColors,
    required this.heatmapColors,
  });

  /// Build tokens for a theme preset. The heatmap ramp is derived from the
  /// preset's own surface and expense colors so it stays on-palette.
  factory AppTokens.fromPreset(ThemePreset preset, {required bool isDark}) {
    final heatmapBase = isDark ? preset.cardColor : preset.backgroundColor;
    return AppTokens(
      success: preset.incomeColor,
      warning: preset.warningColor,
      danger: preset.expenseColor,
      chartColors: preset.chartColors,
      heatmapColors: [
        heatmapBase,
        Color.lerp(heatmapBase, preset.expenseColor, 0.3)!,
        Color.lerp(heatmapBase, preset.expenseColor, 0.55)!,
        Color.lerp(heatmapBase, preset.expenseColor, 0.78)!,
        preset.expenseColor,
      ],
    );
  }

  /// Positive money movement (income, savings, on-track budget).
  final Color success;

  /// Caution (renewal approaching, budget nearing its cap).
  final Color warning;

  /// Negative money movement (expense, urgent renewal, budget exceeded).
  final Color danger;

  /// Categorical palette for charts, in draw order.
  final List<Color> chartColors;

  /// Calendar heatmap ramp, no-activity → highest spend.
  final List<Color> heatmapColors;

  /// Color for a renewal happening in [daysUntilRenewal] days.
  Color urgency(int daysUntilRenewal) {
    if (daysUntilRenewal < AppConstants.renewalUrgentThreshold) return danger;
    if (daysUntilRenewal < AppConstants.renewalWarningThreshold) {
      return warning;
    }
    return success;
  }

  /// Categorical chart color for series/category [index].
  Color chartColor(int index) => chartColors[index % chartColors.length];

  /// Subtle two-stop gradient around the chart color for [index].
  List<Color> chartGradient(int index) {
    final hsl = HSLColor.fromColor(chartColor(index));
    return [
      hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0)).toColor(),
    ];
  }

  /// Tokens for the current theme. Falls back to the default warm palette
  /// when a bare [ThemeData] (e.g. in a widget test) carries no extension.
  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? fallback;

  static const AppTokens fallback = AppTokens(
    success: Color(0xFF48A868),
    warning: Color(0xFFFFB366),
    danger: Color(0xFFE74C3C),
    chartColors: ThemePreset.defaultChartColors,
    heatmapColors: [
      Color(0xFF2B2625),
      Color(0xFF5D3A3A),
      Color(0xFF8B4545),
      Color(0xFFB84C4C),
      Color(0xFFE74C3C),
    ],
  );

  @override
  AppTokens copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    List<Color>? chartColors,
    List<Color>? heatmapColors,
  }) {
    return AppTokens(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      chartColors: chartColors ?? this.chartColors,
      heatmapColors: heatmapColors ?? this.heatmapColors,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      chartColors: [
        for (var i = 0; i < chartColors.length; i++)
          Color.lerp(
            chartColors[i],
            other.chartColors[i % other.chartColors.length],
            t,
          )!,
      ],
      heatmapColors: [
        for (var i = 0; i < heatmapColors.length; i++)
          Color.lerp(
            heatmapColors[i],
            other.heatmapColors[i % other.heatmapColors.length],
            t,
          )!,
      ],
    );
  }
}
