import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/subscription.dart';
import '../providers/subscription_providers.dart';
import '../theme/app_theme.dart';
import 'add_subscription_sheet.dart';

class SubscriptionCard extends ConsumerWidget {
  final Subscription subscription;

  const SubscriptionCard({
    super.key,
    required this.subscription,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final urgencyColor = AppTheme.getRenewalUrgencyColor(
      context,
      subscription.daysUntilRenewal,
    );

    return Dismissible(
      key: Key(subscription.id),
      background: _buildSwipeBackground(context, Alignment.centerLeft, Colors.blue, Icons.edit),
      secondaryBackground: _buildSwipeBackground(context, Alignment.centerRight, Colors.red, Icons.delete),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe left to delete
          return await _showDeleteDialog(context);
        } else {
          // Swipe right to edit
          _showEditDialog(context, ref);
          return false;
        }
      },
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Move to recently deleted instead of permanent delete
          await ref.read(databaseServiceProvider).moveToRecentlyDeleted(subscription.id);
          await ref.read(subscriptionProvider.notifier).loadSubscriptions();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${subscription.name} moved to recently deleted'),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await ref.read(databaseServiceProvider).restoreFromRecentlyDeleted(subscription.id);
                    await ref.read(subscriptionProvider.notifier).loadSubscriptions();
                  },
                ),
              ),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showDetailsSheet(context, ref),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Logo/Icon
                  _buildLogo(context, urgencyColor),

                  const SizedBox(width: 16),

                  // Name and renewal info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: urgencyColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _getRenewalText(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        subscription.formattedPrice,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subscription.billingCycle.displayName.toLowerCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(BuildContext context, Alignment alignment, Color color, IconData icon) {
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

  /// Build logo or placeholder
  Widget _buildLogo(BuildContext context, Color urgencyColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: urgencyColor.withOpacity(0.12),
      ),
      child: Center(
        child: Text(
          subscription.category.icon,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  /// Get renewal text with urgency
  String _getRenewalText() {
    final days = subscription.daysUntilRenewal;

    if (days == 0) {
      return 'Renews today';
    } else if (days == 1) {
      return 'Renews tomorrow';
    } else if (days < 7) {
      return 'Renews in $days days';
    } else if (days < 30) {
      return 'Renews in $days days';
    } else {
      final dateFormat = DateFormat('MMM dd');
      return 'Next: ${dateFormat.format(subscription.nextBillDate)}';
    }
  }

  Future<bool> _showDeleteDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Delete subscription?'),
          content: Text(
            '${subscription.name} will be moved to Recently Deleted. '
            'You can restore it within 30 days.',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddSubscriptionSheet(subscription: subscription),
    );
  }

  void _showDetailsSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final urgencyColor = AppTheme.getRenewalUrgencyColor(
      context,
      subscription.daysUntilRenewal,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
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
                  // Header
                  Row(
                    children: [
                      _buildLogo(context, urgencyColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscription.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              subscription.category.displayName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Details
                  _buildDetailRow(context, 'Price', subscription.formattedPrice),
                  _buildDetailRow(context, 'Billing', subscription.billingCycle.displayName),
                  _buildDetailRow(context, 'Next bill', DateFormat('MMM dd, yyyy').format(subscription.nextBillDate)),
                  _buildDetailRow(context, 'Days until renewal', '${subscription.daysUntilRenewal} days'),
                  _buildDetailRow(context, 'Monthly cost', '\$${subscription.monthlyEquivalent.toStringAsFixed(2)}'),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Archive subscription?'),
                                  content: Text(
                                    'Are you sure you want to archive ${subscription.name}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Archive'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmed == true && context.mounted) {
                              await ref.read(subscriptionProvider.notifier).archiveSubscription(subscription.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${subscription.name} archived'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.archive_outlined, size: 18),
                          label: const Text('Archive'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
