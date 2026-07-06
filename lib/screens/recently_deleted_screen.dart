import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription.dart';
import '../providers/auth_providers.dart';
import '../providers/subscription_providers.dart';
import '../providers/sync_providers.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/common/app_empty_state.dart';

class RecentlyDeletedScreen extends ConsumerStatefulWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  ConsumerState<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends ConsumerState<RecentlyDeletedScreen> {
  List<Subscription> _deletedSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadDeletedSubscriptions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh list when navigating back to this screen
    _loadDeletedSubscriptions();
  }

  void _loadDeletedSubscriptions() {
    final databaseService = ref.read(databaseServiceProvider);
    setState(() {
      _deletedSubscriptions = databaseService.getRecentlyDeletedSubscriptions();
    });
  }

  void _removeItemFromList(String subscriptionId) {
    setState(() {
      _deletedSubscriptions.removeWhere((s) => s.id == subscriptionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final databaseService = ref.watch(databaseServiceProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Recently deleted',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Items will be permanently deleted after 30 days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List or empty state
          Expanded(
            child: _deletedSubscriptions.isEmpty
                ? const AppEmptyState(
                    icon: Icons.delete_outline,
                    title: 'Recently deleted is empty',
                    message:
                        'Deleted subscriptions wait here for 30 days so you '
                        'can restore them, then they are removed for good.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _deletedSubscriptions.length,
                    itemBuilder: (context, index) {
                      final subscription = _deletedSubscriptions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DeletedCard(
                          subscription: subscription,
                          databaseService: databaseService,
                          onItemRemoved: _removeItemFromList,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

}

class _DeletedCard extends ConsumerWidget {

  const _DeletedCard({
    required this.subscription,
    required this.databaseService,
    required this.onItemRemoved,
  });
  final Subscription subscription;
  final DatabaseService databaseService;
  final void Function(String) onItemRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final daysRemaining = databaseService.getDaysUntilPermanentDeletion(subscription);

    // Capture provider and data before widget can be disposed
    final subscriptionNotifier = ref.read(subscriptionProvider.notifier);
    final subscriptionId = subscription.id;
    final subscriptionName = subscription.name;
    final isSyncEnabled = ref.read(isSyncEnabledProvider);
    final currentUser = ref.read(currentFirebaseUserProvider);

    return Dismissible(
      key: Key(subscription.id),
      background: _buildSwipeBackground(
        context,
        Alignment.centerLeft,
        Colors.green,
        Icons.restore,
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        Alignment.centerRight,
        Colors.red,
        Icons.delete_forever,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete permanently
          return _showDeleteDialog(context);
        } else {
          // Restore
          return true;
        }
      },
      onDismissed: (direction) async {
        // CRITICAL: Remove item from list immediately so Dismissible can be removed from tree
        onItemRemoved(subscriptionId);

        if (direction == DismissDirection.endToStart) {
          // Delete permanently
          await databaseService.deleteSubscription(subscriptionId);

          if (isSyncEnabled && currentUser != null) {
            unawaited(
              SyncService().deleteRemoteSubscription(
                currentUser.uid,
                subscriptionId,
              ),
            );
          }

          showAppToast('$subscriptionName deleted permanently');
        } else {
          // Restore — notifier reschedules notifications + re-pushes to remote.
          await subscriptionNotifier.restoreFromRecentlyDeleted(subscriptionId);
          showAppToast('$subscriptionName restored');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showActionsSheet(context, ref),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: 0.5,
                        child: Text(
                          subscription.category.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Name and info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            decoration: TextDecoration.lineThrough,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Deletes in $daysRemaining ${daysRemaining == 1 ? 'day' : 'days'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Price
                  Text(
                    subscription.formattedPrice,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tap-to-open actions sheet — alternative to swipe gestures.
  void _showActionsSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Capture all ref-derived values UP FRONT — by the time the user
    // taps Restore/Delete, the sheet's button onPressed runs, then
    // loadSubscriptions rebuilds the parent list, and this _DeletedCard
    // ConsumerWidget is removed from the tree. `ref.read(...)` after
    // that point throws "Cannot use ref after the widget was disposed".
    final notifier = ref.read(subscriptionProvider.notifier);
    final isSyncEnabled = ref.read(isSyncEnabledProvider);
    final user = ref.read(currentFirebaseUserProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    subscription.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Auto-deletes in ${databaseService.getDaysUntilPermanentDeletion(subscription)} days',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            onItemRemoved(subscription.id);
                            // Notifier reschedules notifications + re-pushes.
                            await notifier.restoreFromRecentlyDeleted(subscription.id);
                            showAppToast('${subscription.name} restored');
                          },
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Restore'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await _showDeleteDialog(sheetContext);
                            if (!confirmed) return;
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                            onItemRemoved(subscription.id);
                            await databaseService.deleteSubscription(subscription.id);
                            if (isSyncEnabled && user != null) {
                              unawaited(
                                SyncService().deleteRemoteSubscription(
                                  user.uid,
                                  subscription.id,
                                ),
                              );
                            }
                            showAppToast('${subscription.name} deleted permanently');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                          ),
                          icon: const Icon(Icons.delete_forever, size: 18),
                          label: const Text('Delete Forever'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context,
    Alignment alignment,
    Color color,
    IconData icon,
  ) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Future<bool> _showDeleteDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Delete permanently?'),
              content: Text(
                'This will permanently delete ${subscription.name}. This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Delete Forever'),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
