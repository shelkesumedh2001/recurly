import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'constants.dart';

/// In-app "what's new" changelog.
///
/// [kAppBuild] must be bumped together with `pubspec.yaml`'s `version:` on
/// each release, and a matching [ChangelogRelease] added to [kChangelog]
/// (newest first). The sheet auto-shows once per upgrade: never on first
/// install, never on downgrade (mirrors Minus's `decideChangelog` pattern).
const String kAppBuild = '1.0.1+6';

class ChangelogRelease {
  const ChangelogRelease({required this.build, required this.notes});
  final String build;
  final List<String> notes;
}

const List<ChangelogRelease> kChangelog = [
  ChangelogRelease(
    build: '1.0.1+6',
    notes: [
      'New: quick setup when you first open the app — pick your currency and theme',
      'Back up and restore your data to a file',
      'Monthly budget forecast: see projected spend and whether you’ll go over',
      'Rename your household and what you call the other member',
      'Refreshed charts and a cleaner analytics look',
      'Your sort order is now remembered, and long amounts no longer wrap',
      'Clearer category colors on the Ocean theme',
    ],
  ),
  ChangelogRelease(
    build: '1.0.0+5',
    notes: [
      'New: track credit cards — statement dates, payment due dates, and which subscriptions bill to each card',
      'Changes made offline now sync reliably once you reconnect',
      "Reminders cover your next few renewals, even if you don't open the app for a while",
      'Tap a reminder to jump straight into the app',
      'Accurate totals when subscriptions use different currencies',
      'Deleted subscriptions stop sending reminders and stay deleted across devices',
      'Category picker shows your most-used categories first',
      'Smaller, faster app build',
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
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
