import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_status.dart';
import '../providers/auth_providers.dart';
import '../providers/sync_providers.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncStatusAsync = ref.watch(syncStatusProvider);
    final isSignedIn = ref.watch(isSignedInProvider);

    if (!isSignedIn) return const SizedBox.shrink();

    final syncStatus = syncStatusAsync.value ?? SyncStatus.idle;

    IconData icon;
    Color color;
    String tooltip;

    switch (syncStatus) {
      case SyncStatus.synced:
        icon = Icons.cloud_done_outlined;
        color = theme.colorScheme.primary;
        tooltip = 'Synced';
      case SyncStatus.syncing:
        icon = Icons.cloud_sync_outlined;
        color = theme.colorScheme.tertiary;
        tooltip = 'Syncing...';
      case SyncStatus.error:
        icon = Icons.cloud_off_outlined;
        color = theme.colorScheme.error;
        tooltip = 'Sync error — tap to retry';
      case SyncStatus.offline:
        icon = Icons.cloud_off_outlined;
        color = theme.colorScheme.onSurface.withValues(alpha: 0.4);
        tooltip = 'Offline';
      default:
        return const SizedBox.shrink();
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: syncStatus == SyncStatus.error
            ? () {
                final user = ref.read(currentFirebaseUserProvider);
                if (user != null) {
                  ref.read(syncServiceProvider).forceSync(user.uid);
                }
              }
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: syncStatus == SyncStatus.syncing
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
