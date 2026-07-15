import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/subscription.dart';
import '../providers/credit_card_providers.dart';
import '../providers/household_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/subscription_providers.dart';
import '../theme/app_tokens.dart';
import 'add_subscription_sheet.dart';
import 'app_toast.dart';
import 'common/app_dialogs.dart';
import 'common/detail_row.dart';
import 'split_subscription_sheet.dart';
import 'trial/trial_badge.dart';

class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.isPartnerSub = false,
    this.showSwipeHint = false,
  });
  final Subscription subscription;
  final bool isPartnerSub;
  final bool showSwipeHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final urgencyColor =
        AppTokens.of(context).urgency(subscription.daysUntilRenewal);

    // Capture providers and data before widget can be disposed
    final subscriptionNotifier = ref.read(subscriptionProvider.notifier);
    final subscriptionId = subscription.id;
    final subscriptionName = subscription.name;

    // Partner subs are read-only (no swipe, no context menu)
    if (isPartnerSub) {
      return _buildCardContent(context, ref, theme, urgencyColor);
    }

    final card = Dismissible(
      key: Key(subscription.id),
      background: _buildSwipeBackground(
          context, Alignment.centerLeft, Colors.blue, Icons.edit,),
      secondaryBackground: _buildSwipeBackground(
          context, Alignment.centerRight, Colors.red, Icons.delete,),
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
          // Notifier handles cancelling notifications + remote sync.
          await subscriptionNotifier.moveToRecentlyDeleted(subscriptionId);

          // Use a custom Overlay-based toast — the previous SnackBar
          // approach didn't auto-dismiss in this app's nested-Scaffold
          // + FAB layout (animation status never reached `completed`,
          // so the messenger's internal timer never armed).
          showAppToast(
            '$subscriptionName moved to recently deleted',
            actionLabel: 'Undo',
            onAction: () async {
              // Notifier reschedules notifications + re-pushes to remote.
              await subscriptionNotifier
                  .restoreFromRecentlyDeleted(subscriptionId);
            },
          );
        }
      },
      child: _buildCardContent(context, ref, theme, urgencyColor),
    );

    if (showSwipeHint) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          card,
          _SwipeHintBar(),
        ],
      );
    }

    return card;
  }

  Widget _buildCardContent(BuildContext context, WidgetRef ref, ThemeData theme,
      Color urgencyColor,) {
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2,),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiary
                                    .withValues(alpha: 0.15),
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
                            TrialBadge(
                                subscription: subscription, compact: true,),
                          ],
                          if (_hasSplit()) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.call_split,
                              size: 16,
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.6),
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
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
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
                    if (subscription.isFreeTrial &&
                        subscription.priceAfterTrial != null)
                      Text(
                        '${subscription.currencySymbol}${subscription.priceAfterTrial!.toStringAsFixed(2)} after',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      Text(
                        subscription.billingCycle.displayName.toLowerCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
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

  Widget _buildSwipeBackground(
      BuildContext context, Alignment alignment, Color color, IconData icon,) {
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

  Future<bool> _showDeleteDialog(BuildContext context) {
    return showConfirmDialog(
      context,
      title: 'Delete subscription?',
      message: '${subscription.name} will move to Recently deleted. '
          'You can restore it within 30 days.',
      confirmLabel: 'Delete',
      destructive: true,
    );
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
    final urgencyColor =
        AppTokens.of(context).urgency(subscription.daysUntilRenewal);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          // Cap the height so long detail lists (trial + split + card)
          // scroll instead of overflowing on small screens.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle (the floating card suppresses the framework
                  // one, so each floating sheet draws its own).
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header: logo, name/category, renewal countdown pill
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
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RenewalPill(
                        days: subscription.daysUntilRenewal,
                        color: urgencyColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Partner badge
                  if (isPartnerSub) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people,
                            size: 16,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${ref.read(partnerLabelProvider)}'s subscription",
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
                  DetailRow('Price', subscription.formattedPrice),
                  DetailRow('Billing', subscription.billingCycle.displayName),
                  DetailRow(
                    'Next bill',
                    '${DateFormat('MMM dd, yyyy').format(subscription.nextBillDate)}'
                        ' · ${_renewalCountdownText()}',
                  ),
                  DetailRow(
                    'Monthly cost',
                    '${subscription.currencySymbol}${subscription.monthlyEquivalent.toStringAsFixed(2)}',
                  ),
                  if (subscription.cardId != null)
                    if (ref.read(cardByIdProvider(subscription.cardId))
                        case final card?)
                      DetailRow(
                        'Card',
                        '${card.name} · payment due ${DateFormat('MMM d').format(card.nextDueDate)}',
                      ),
                  if (_hasSplit()) ...[
                    DetailRow(
                      'Split',
                      "${(subscription.splitWith!.first['sharePercent'] as num).toInt()}% ${ref.read(partnerLabelProvider)}'s share",
                    ),
                    DetailRow(
                      'Your share',
                      '${subscription.currencySymbol}${(subscription.price * (1 - (subscription.splitWith!.first['sharePercent'] as num) / 100)).toStringAsFixed(2)}',
                    ),
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
                          _hasSplit()
                              ? 'Manage split'
                              : 'Split with ${ref.read(partnerLabelProvider)}',
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Actions. The sheet dismisses by swipe/scrim, so own subs
                  // don't need a Close button.
                  if (isPartnerSub)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditDialog(context, ref);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              // Capture the notifier BEFORE any await —
                              // after Navigator.pop this card may be
                              // disposed and ref unusable.
                              final notifier =
                                  ref.read(subscriptionProvider.notifier);

                              final confirmed = await showConfirmDialog(
                                context,
                                title: 'Archive subscription?',
                                message: '${subscription.name} moves to '
                                    'Archived and stops counting toward '
                                    'your totals. You can unarchive it '
                                    'any time.',
                                confirmLabel: 'Archive',
                              );
                              if (!confirmed) return;
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                              await notifier
                                  .archiveSubscription(subscription.id);
                              showAppToast(
                                '${subscription.name} archived',
                                actionLabel: 'Undo',
                                onAction: () async {
                                  await notifier
                                      .unarchiveSubscription(subscription.id);
                                },
                              );
                            },
                            icon: const Icon(Icons.archive_outlined, size: 18),
                            label: const Text('Archive'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          // Capture before awaits (see Archive above).
                          final notifier =
                              ref.read(subscriptionProvider.notifier);

                          final confirmed = await _showDeleteDialog(context);
                          if (!confirmed) return;
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                          // Notifier cancels notifications + syncs remote.
                          await notifier.moveToRecentlyDeleted(subscription.id);
                          showAppToast(
                            '${subscription.name} moved to recently deleted',
                            actionLabel: 'Undo',
                            onAction: () async {
                              await notifier
                                  .restoreFromRecentlyDeleted(subscription.id);
                            },
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        icon: const Icon(Icons.delete_outlined, size: 18),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// "renews today" / "in 3 days" for the merged next-bill row.
  String _renewalCountdownText() {
    final days = subscription.daysUntilRenewal;
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}

class _SwipeHintBar extends StatefulWidget {
  @override
  State<_SwipeHintBar> createState() => _SwipeHintBarState();
}

class _SwipeHintBarState extends State<_SwipeHintBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _height;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _height = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _controller.duration = AppMotion.of(context, _controller.duration!);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    );
    return SizeTransition(
      sizeFactor: _height,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _opacity,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2, left: 8, right: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\u2190 swipe to edit', style: hintStyle),
              Text('swipe to delete \u2192', style: hintStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Urgency-tinted countdown pill for the details sheet header.
class _RenewalPill extends StatelessWidget {
  const _RenewalPill({required this.days, required this.color});

  final int days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = days == 0
        ? 'today'
        : days == 1
            ? 'tomorrow'
            : '$days days';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
