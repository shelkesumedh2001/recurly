import 'package:hive/hive.dart';

/// Current Hive schema version. Bump whenever a breaking @HiveField change
/// lands (removed field, changed field index, incompatible type swap) and
/// extend [migrateSchema] with the corresponding from→to branch.
const int kCurrentSchemaVersion = 1;

const String _schemaVersionKey = 'schemaVersion';

/// Ensure the stored schema version matches [kCurrentSchemaVersion].
///
/// - If no version is stored, writes the current version (fresh install or
///   first run after this scaffolding lands).
/// - If the stored version equals the current version, no-op.
/// - If the stored version is older, runs the migration chain (none yet).
/// - If the stored version is newer than this build knows about (downgrade),
///   throws [StateError] — we refuse to silently touch data from the future.
Future<void> migrateSchema(Box<dynamic> settingsBox) async {
  final stored = settingsBox.get(_schemaVersionKey);

  if (stored == null) {
    await settingsBox.put(_schemaVersionKey, kCurrentSchemaVersion);
    return;
  }

  if (stored is! int) {
    throw StateError(
      'Invalid schemaVersion in settings box: $stored (${stored.runtimeType})',
    );
  }

  if (stored == kCurrentSchemaVersion) {
    return;
  }

  if (stored > kCurrentSchemaVersion) {
    throw StateError(
      'Hive schemaVersion $stored is newer than this build supports '
      '($kCurrentSchemaVersion). Refusing to downgrade data.',
    );
  }

  // stored < kCurrentSchemaVersion — run sequential migrations here.
  // No migrations defined yet; v1 is the baseline.
  await settingsBox.put(_schemaVersionKey, kCurrentSchemaVersion);
}
