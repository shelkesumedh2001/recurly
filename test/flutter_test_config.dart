import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file in test/.
///
/// Loads the real fonts listed in FontManifest.json (MaterialIcons) so
/// golden images render actual icon glyphs instead of empty boxes. Text
/// still renders with the deterministic Ahem test font, which is fine for
/// goldens — layout and glyph boxes shift if anything regresses.
Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadManifestFonts();
  await testMain();
}

Future<void> _loadManifestFonts() async {
  final manifestJson = await rootBundle.loadString('FontManifest.json');
  final manifest = json.decode(manifestJson) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font in (entry['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
