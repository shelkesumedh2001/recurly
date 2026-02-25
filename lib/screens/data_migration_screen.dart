import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class DataMigrationScreen extends ConsumerStatefulWidget {
  const DataMigrationScreen({super.key});

  @override
  ConsumerState<DataMigrationScreen> createState() =>
      _DataMigrationScreenState();
}

class _DataMigrationScreenState extends ConsumerState<DataMigrationScreen> {
  bool _isMigrating = false;
  bool _isDone = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localCount = DatabaseService().getActiveSubscriptions().length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Cloud Migration'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDone ? Icons.cloud_done : Icons.cloud_upload_outlined,
                size: 64,
                color: _isDone
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              _isDone ? 'Migration Complete!' : 'Upload to Cloud?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              _isDone
                  ? 'Your subscriptions are now synced to the cloud.'
                  : 'Found $localCount subscription${localCount == 1 ? '' : 's'} '
                      'on this device. Upload them to the cloud for backup and cross-device sync?',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            if (_isDone)
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Done'),
              )
            else ...[
              FilledButton(
                onPressed: _isMigrating ? null : _startMigration,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isMigrating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Upload Now'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startMigration() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;

    setState(() => _isMigrating = true);
    try {
      await SyncService().uploadLocalData(user.uid);
      if (mounted) setState(() => _isDone = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }
}
