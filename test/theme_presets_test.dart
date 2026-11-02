import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/theme/app_tokens.dart';
import 'package:recurly/theme/theme_presets.dart';

void main() {
  // BUG-19: Ocean's cyan subtext made unselected nav tabs look selected
  // next to the aqua accent (Forest had the same with greens). Secondary
  // text must stay near-neutral so only the accent reads as "selected".
  test('every preset keeps secondary text near-neutral', () {
    for (final preset in ThemePresets.all) {
      final hsv = HSVColor.fromColor(preset.subtextColor);
      expect(hsv.saturation, lessThanOrEqualTo(0.2), reason: preset.name);
    }
  });

  // BUG-17 follow-up: custom categories come after the 6 built-ins; the
  // palette used to wrap, so the first custom category was drawn in
  // Entertainment's colour.
  test('custom-category colours differ from every built-in colour', () {
    double hueGap(Color a, Color b) {
      final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
      return d > 180 ? 360 - d : d;
    }

    for (final preset in ThemePresets.all) {
      final tokens = AppTokens.fromPreset(
        preset,
        isDark: preset.brightness == Brightness.dark,
      );
      final builtIns = preset.chartColors;
      for (var i = builtIns.length; i < builtIns.length + 4; i++) {
        for (final b in builtIns) {
          expect(hueGap(tokens.chartColor(i), b), greaterThan(8),
              reason: '${preset.name} custom #${i - builtIns.length}',);
        }
      }
    }
  });
}
