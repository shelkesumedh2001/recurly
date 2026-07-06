import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/services/theme_service.dart';

/// Guards the accent-color bug: `Color.r/g/b` are 0.0–1.0 doubles, so a
/// bare `.toInt()` floored every channel to 0 and turned every accent into
/// black (#000000).
void main() {
  final service = ThemeService();

  group('colorToHex', () {
    test('encodes a mid-range color, not black', () {
      // Coral #F4A089 — the app's default accent.
      expect(service.colorToHex(const Color(0xFFF4A089)), '#F4A089');
    });

    test('encodes pure channels', () {
      expect(service.colorToHex(const Color(0xFFFF0000)), '#FF0000');
      expect(service.colorToHex(const Color(0xFF00FF00)), '#00FF00');
      expect(service.colorToHex(const Color(0xFF0000FF)), '#0000FF');
    });

    test('encodes black and white at the extremes', () {
      expect(service.colorToHex(const Color(0xFF000000)), '#000000');
      expect(service.colorToHex(const Color(0xFFFFFFFF)), '#FFFFFF');
    });

    test('round-trips through parseHexColor', () {
      for (final color in const [
        Color(0xFFF4A089),
        Color(0xFF64B5F6),
        Color(0xFF81C784),
        Color(0xFF123456),
      ]) {
        final hex = service.colorToHex(color);
        final parsed = service.parseHexColor(hex)!;
        expect(service.colorToHex(parsed), hex);
      }
    });
  });

  group('parseHexColor', () {
    test('parses with and without the leading #', () {
      expect(service.parseHexColor('#F4A089'), const Color(0xFFF4A089));
      expect(service.parseHexColor('F4A089'), const Color(0xFFF4A089));
    });

    test('rejects malformed input', () {
      expect(service.parseHexColor(null), isNull);
      expect(service.parseHexColor(''), isNull);
      expect(service.parseHexColor('#12'), isNull);
      expect(service.parseHexColor('nothex'), isNull);
    });
  });
}
