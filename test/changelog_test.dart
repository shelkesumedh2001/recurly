import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/utils/changelog.dart';

void main() {
  group('decideChangelog', () {
    test('first install (null lastSeen) → never show', () {
      expect(decideChangelog(kAppBuild, null), isNull);
    });

    test('same build → skip', () {
      expect(decideChangelog(kAppBuild, kAppBuild), isNull);
    });

    test('upgrade with a matching release entry → show it', () {
      final release = decideChangelog(kAppBuild, '1.0.0+4');
      expect(release, isNotNull);
      expect(release!.build, kAppBuild);
      expect(release.notes, isNotEmpty);
    });

    test('upgrade with no matching entry → skip gracefully', () {
      expect(decideChangelog('9.9.9+99', '1.0.0+4'), isNull);
    });

    test('kAppBuild has a changelog entry (release checklist guard)', () {
      expect(kChangelog.any((r) => r.build == kAppBuild), isTrue,
          reason: 'Bump kAppBuild AND add its ChangelogRelease together',);
    });
  });
}
