import 'package:flutter/material.dart';
import '../../models/budget.dart';

/// Alert card displayed when budget warning/exceeded
class BudgetAlertCard extends StatelessWidget {
  const BudgetAlertCard({
    super.key,
    required this.status,
    required this.usage,
    required this.budget,
    required this.spent,
    this.onDismiss,
    this.onTap,
  });

  final BudgetStatus status;
  final double usage;
  final double budget;
  final double spent;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status == BudgetStatus.safe || status == BudgetStatus.noBudget) {
      return const SizedBox.shrink();
    }

    final isExceeded = status == BudgetStatus.exceeded;
    final color = isExceeded
        ? theme.colorScheme.error
        : theme.colorScheme.tertiary;

    final backgroundColor = color.withValues(alpha: 0.1);
    final borderColor = color.withValues(alpha: 0.3);

    final overspent = spent - budget;
    final percentage = (usage * 100).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isExceeded
                        ? Icons.error_outline_rounded
                        : Icons.warning_amber_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExceeded
                            ? 'Budget Exceeded'
                            : 'Approaching Budget Limit',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isExceeded
                            ? 'You\'ve spent ${_formatCurrency(overspent)} over your budget'
                            : 'You\'ve used $percentage% of your monthly budget',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    onPressed: onDismiss,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    color: color.withValues(alpha: 0.2),
                  ),
                  FractionallySizedBox(
                    widthFactor: usage.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatCurrency(spent)} spent',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '${_formatCurrency(budget)} budget',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '\$${amount.toStringAsFixed(2)}';
  }
}
