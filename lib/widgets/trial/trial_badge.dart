import 'package:flutter/material.dart';
import '../../models/subscription.dart';

/// Badge to display trial status on subscription cards
class TrialBadge extends StatelessWidget {
  const TrialBadge({
    super.key,
    required this.subscription,
    this.compact = false,
  });

  final Subscription subscription;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!subscription.isFreeTrial) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final days = subscription.daysUntilTrialEnds;
    final isExpired = subscription.isTrialExpired;

    // Determine color based on urgency
    Color badgeColor;
    Color textColor;
    if (isExpired) {
      badgeColor = theme.colorScheme.error.withValues(alpha: 0.15);
      textColor = theme.colorScheme.error;
    } else if (days <= 3) {
      badgeColor = theme.colorScheme.error.withValues(alpha: 0.15);
      textColor = theme.colorScheme.error;
    } else if (days <= 7) {
      badgeColor = theme.colorScheme.tertiary.withValues(alpha: 0.15);
      textColor = theme.colorScheme.tertiary;
    } else {
      badgeColor = theme.colorScheme.primary.withValues(alpha: 0.15);
      textColor = theme.colorScheme.primary;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'TRIAL',
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired ? Icons.warning_amber_rounded : Icons.schedule,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            _getBadgeText(),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getBadgeText() {
    if (subscription.trialEndDate == null) return 'FREE TRIAL';

    final days = subscription.daysUntilTrialEnds;
    if (days < 0) return 'EXPIRED';
    if (days == 0) return 'ENDS TODAY';
    if (days == 1) return '1 DAY LEFT';
    return '$days DAYS LEFT';
  }
}

/// Card to show expiring trials prominently
class TrialExpiryCard extends StatelessWidget {
  const TrialExpiryCard({
    super.key,
    required this.subscription,
    this.onTap,
  });

  final Subscription subscription;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = subscription.daysUntilTrialEnds;
    final isExpired = subscription.isTrialExpired;

    // Determine gradient colors based on urgency
    List<Color> gradientColors;
    if (isExpired || days <= 1) {
      gradientColors = [
        theme.colorScheme.error,
        theme.colorScheme.error.withValues(alpha: 0.7),
      ];
    } else if (days <= 3) {
      gradientColors = [
        theme.colorScheme.tertiary,
        theme.colorScheme.tertiary.withValues(alpha: 0.7),
      ];
    } else {
      gradientColors = [
        theme.colorScheme.primary,
        theme.colorScheme.primary.withValues(alpha: 0.7),
      ];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subscription.trialStatusText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Price after trial
                if (subscription.priceAfterTrial != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${subscription.priceAfterTrial!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'after trial',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
