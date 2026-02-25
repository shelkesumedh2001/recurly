import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/analytics_providers.dart';
import '../../providers/currency_providers.dart';
import '../../theme/app_theme.dart';

class MonthlyComparisonChip extends ConsumerWidget {
  const MonthlyComparisonChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparison = ref.watch(monthlyComparisonProvider);
    if (comparison == null || comparison.delta == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    final isIncrease = comparison.delta > 0;
    final color = isIncrease ? AppTheme.expenseColor : AppTheme.incomeColor;
    final icon = isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final prefix = isIncrease ? '+' : '';
    final formattedDelta = currencyService.formatAmount(comparison.delta.abs(), displayCurrency);
    final percentText = '${comparison.percentChange.abs().toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$prefix$formattedDelta ($percentText) vs last month',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
