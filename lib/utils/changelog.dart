import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'constants.dart';

/// In-app "what's new" changelog.
///
/// [kAppBuild] must be bumped together with `pubspec.yaml`'s `version:` on
/// each release, and a matching [ChangelogRelease] added to [kChangelog]
/// (newest first). The sheet auto-shows once per upgrade: never on first
/// install, never on downgrade (mirrors Minus's `decideChangelog` pattern).
const String kAppBuild = '1.0.0+5';

class ChangelogRelease {
  const ChangelogRelease({required this.build, required this.notes});
  final String build;
  final List<String> notes;
}

const List<ChangelogRelease> kChangelog = [
  ChangelogRelease(
    build: '1.0.0+5',
    notes: [
      'Accurate totals when subscriptions use different currencies',
      'Deleted subscriptions now stop sending reminders',
      'Deletes and restores sync reliably across your devices',
      'Recently Deleted now auto-cleans after 30 days',
      'Category picker shows your most-used categories first',
    ],
  ),
  ChangelogRelease(
    build: '1.0.0+4',
    notes: [
      'Fixed Google Sign-In on Play Store builds',
      'Trial subscriptions: optional price and duration picker',
      'New trial-end reminders (1/3/7 days before)',
      'Custom billing cycles',
    ],
  ),
];

const String _lastSeenKey = 'changelogLastSeenBuild';

/// Pure decision: show only on a genuine upgrade.
/// Returns the release to show, or null.
ChangelogRelease? decideChangelog(String currentBuild, String? lastSeen) {
  if (lastSeen == null) return null; // first install — baseline silently
  if (lastSeen == currentBuild) return null;
  final entry = kChangelog.where((r) => r.build == currentBuild);
  return entry.isEmpty ? null : entry.first;
}

/// Call once after first frame. Reads/writes the last-seen build in the
/// schema box (already opened by DatabaseService.initialize).
Future<void> showChangelogIfUpdated(BuildContext context) async {
  final box = await Hive.openBox<dynamic>(AppConstants.schemaBox);
  final lastSeen = box.get(_lastSeenKey) as String?;

  if (lastSeen == null) {
    await box.put(_lastSeenKey, kAppBuild); // baseline on first run
    return;
  }

  final release = decideChangelog(kAppBuild, lastSeen);
  await box.put(_lastSeenKey, kAppBuild);
  if (release == null || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What's new in ${release.build.split('+').first}",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ...release.notes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: theme.textTheme.bodyLarge),
                      Expanded(
                        child: Text(note, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Nice!'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
