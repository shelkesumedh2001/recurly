import 'package:flutter/material.dart';
import '../../models/budget.dart';

/// Visual progress bar showing budget usage
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.usage,
    required this.status,
    this.height = 8,
    this.showLabel = true,
    this.compact = false,
  });

  /// Usage percentage (0.0 to 1.0+)
  final double usage;

  /// Current budget status
  final BudgetStatus status;

  /// Height of the progress bar
  final double height;

  /// Whether to show the percentage label
  final bool showLabel;

  /// Compact mode (smaller)
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (usage * 100).clamp(0, 999).toInt();
    final clampedUsage = usage.clamp(0.0, 1.0);

    final Color progressColor;
    final Color backgroundColor;

    switch (status) {
      case BudgetStatus.safe:
        progressColor = theme.colorScheme.secondary; // Green
        backgroundColor = theme.colorScheme.secondary.withValues(alpha: 0.2);
        break;
      case BudgetStatus.warning:
        progressColor = theme.colorScheme.tertiary; // Amber
        backgroundColor = theme.colorScheme.tertiary.withValues(alpha: 0.2);
        break;
      case BudgetStatus.exceeded:
        progressColor = theme.colorScheme.error; // Red
        backgroundColor = theme.colorScheme.error.withValues(alpha: 0.2);
        break;
      case BudgetStatus.noBudget:
        progressColor = theme.colorScheme.outline;
        backgroundColor = theme.colorScheme.outline.withValues(alpha: 0.1);
        break;
    }

    if (compact) {
      return _buildCompact(
        context,
        clampedUsage,
        progressColor,
        backgroundColor,
        percentage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      status.displayName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: progressColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (status == BudgetStatus.exceeded) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.warning_rounded,
                        size: 14,
                        color: progressColor,
                      ),
                    ],
                  ],
                ),
                Text(
                  '$percentage%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Stack(
            children: [
              // Background track
              Container(
                height: height,
                width: double.infinity,
                color: backgroundColor,
              ),
              // Progress fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                height: height,
                width: double.infinity,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: clampedUsage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(
    BuildContext context,
    double clampedUsage,
    Color progressColor,
    Color backgroundColor,
    int percentage,
  ) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: Stack(
              children: [
                Container(
                  height: height,
                  color: backgroundColor,
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  height: height,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: clampedUsage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: progressColor,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            '$percentage%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }
}
