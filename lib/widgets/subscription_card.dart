import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/subscription.dart';
import '../providers/auth_providers.dart';
import '../providers/household_providers.dart';
import '../providers/subscription_providers.dart';
import '../providers/sync_providers.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'add_subscription_sheet.dart';
import 'split_subscription_sheet.dart';
import 'trial/trial_badge.dart';

class SubscriptionCard extends ConsumerWidget {

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.isPartnerSub = false,
  });
  final Subscription subscription;
  final bool isPartnerSub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final urgencyColor = AppTheme.getRenewalUrgencyColor(
      context,
      subscription.daysUntilRenewal,
    );

    // Capture providers and data before widget can be disposed
    final databaseService = ref.read(databaseServiceProvider);
    final subscriptionNotifier = ref.read(subscriptionProvider.notifier);
    final subscriptionId = subscription.id;
    final subscriptionName = subscription.name;

    // Partner subs are read-only (no swipe)
    if (isPartnerSub) {
      return _buildCardContent(context, ref, theme, urgencyColor);
    }

    return Dismissible(
      key: Key(subscription.id),
      background: _buildSwipeBackground(context, Alignment.centerLeft, Colors.blue, Icons.edit),
      secondaryBackground: _buildSwipeBackground(context, Alignment.centerRight, Colors.red, Icons.delete),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe left to delete
          return _showDeleteDialog(context);
        } else {
          // Swipe right to edit
          _showEditDialog(context, ref);
          return false;
        }
      },
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Move to recently deleted instead of permanent delete
          await databaseService.moveToRecentlyDeleted(subscriptionId);
          await subscriptionNotifier.loadSubscriptions();

          // Also delete from Firestore so it doesn't come back on sync
          final isSyncEnabled = ref.read(isSyncEnabledProvider);
          final user = ref.read(currentFirebaseUserProvider);
          if (isSyncEnabled && user != null) {
            SyncService().deleteRemoteSubscription(user.uid, subscriptionId);
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$subscriptionName moved to recently deleted'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await databaseService.restoreFromRecentlyDeleted(subscriptionId);
                    await subscriptionNotifier.loadSubscriptions();
                    // Re-push to Firestore on undo
                    if (isSyncEnabled && user != null) {
                      final restored = databaseService.getSubscriptionById(subscriptionId);
                      if (restored != null) {
                        SyncService().pushSubscription(user.uid, restored);
                      }
                    }
                  },
                ),
              ),
            );
          }
        }
      },
      child: _buildCardContent(context, ref, theme, urgencyColor),
    );
  }

  Widget _buildCardContent(BuildContext context, WidgetRef ref, ThemeData theme, Color urgencyColor) {
    return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.08),
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
                        Row(
                          children: [
                            if (isPartnerSub) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.people,
                                  size: 14,
                                  color: theme.colorScheme.tertiary,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                subscription.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (subscription.isFreeTrial) ...[
                              const SizedBox(width: 8),
                              TrialBadge(subscription: subscription, compact: true),
                            ],
                            if (_hasSplit()) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.call_split,
                                size: 16,
                                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                              ),
                            ],
                          ],
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
                                subscription.isFreeTrial
                                    ? subscription.trialStatusText
                                    : _getRenewalText(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                        subscription.isFreeTrial && subscription.price == 0
                            ? 'FREE'
                            : subscription.formattedPrice,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: subscription.isFreeTrial
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (subscription.isFreeTrial && subscription.priceAfterTrial != null)
                        Text(
                          '${subscription.currencySymbol}${subscription.priceAfterTrial!.toStringAsFixed(2)} after',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          subscription.billingCycle.displayName.toLowerCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    // If logoUrl exists, try to load network image
    if (subscription.logoUrl != null && subscription.logoUrl!.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: urgencyColor.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              subscription.logoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to emoji if image fails
                return Container(
                  color: urgencyColor.withValues(alpha: 0.12),
                  child: Center(
                    child: Text(
                      subscription.category.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // Original emoji fallback
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: urgencyColor.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Text(
          subscription.category.icon,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  /// Check if subscription has a split
  bool _hasSplit() {
    return subscription.splitWith != null && subscription.splitWith!.isNotEmpty;
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
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Partner badge
                  if (isPartnerSub) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, size: 16, color: theme.colorScheme.tertiary),
                          const SizedBox(width: 6),
                          Text(
                            'Partner\'s Subscription',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Details
                  _buildDetailRow(context, 'Price', subscription.formattedPrice),
                  _buildDetailRow(context, 'Billing', subscription.billingCycle.displayName),
                  _buildDetailRow(context, 'Next bill', DateFormat('MMM dd, yyyy').format(subscription.nextBillDate)),
                  _buildDetailRow(context, 'Days until renewal', '${subscription.daysUntilRenewal} days'),
                  _buildDetailRow(context, 'Monthly cost', '${subscription.currencySymbol}${subscription.monthlyEquivalent.toStringAsFixed(2)}'),
                  if (_hasSplit()) ...[
                    _buildDetailRow(context, 'Split', '${(subscription.splitWith!.first['sharePercent'] as num).toInt()}% partner\'s share'),
                    _buildDetailRow(context, 'Your share', '${subscription.currencySymbol}${(subscription.price * (1 - (subscription.splitWith!.first['sharePercent'] as num) / 100)).toStringAsFixed(2)}'),
                  ],

                  // Split button (only for own subs in a household)
                  if (!isPartnerSub && ref.read(isInHouseholdProvider)) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => SplitSubscriptionSheet(
                              subscription: subscription,
                            ),
                          );
                        },
                        icon: const Icon(Icons.call_split, size: 18),
                        label: Text(
                          _hasSplit() ? 'Manage Split' : 'Split with Partner',
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action buttons
                  if (isPartnerSub)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    )
                  else
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
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
