import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/analytics_providers.dart';
import '../../providers/currency_providers.dart';
import '../../theme/app_theme.dart';

class WhoPaysMoresBar extends ConsumerStatefulWidget {
  const WhoPaysMoresBar({super.key});

  @override
  ConsumerState<WhoPaysMoresBar> createState() => _WhoPaysMoresBarState();
}

class _WhoPaysMoresBarState extends ConsumerState<WhoPaysMoresBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comparison = ref.watch(householdSpendComparisonProvider);
    if (comparison == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    final myColor = AppTheme.primaryCoral;
    final partnerColor = const Color(0xFF2BBCC4); // teal from chart colors

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Household Spending',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return Column(
                children: [
                  // You
                  _buildBar(
                    theme,
                    label: 'You',
                    amount: currencyService.formatAmount(comparison.myTotal, displayCurrency),
                    percent: comparison.myPercent,
                    color: myColor,
                  ),
                  const SizedBox(height: 14),
                  // Partner
                  _buildBar(
                    theme,
                    label: 'Partner',
                    amount: currencyService.formatAmount(comparison.partnerTotal, displayCurrency),
                    percent: comparison.partnerPercent,
                    color: partnerColor,
                  ),
                  const SizedBox(height: 14),
                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        '${currencyService.formatAmount(comparison.total, displayCurrency)}/mo',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildBar(
    ThemeData theme, {
    required String label,
    required String amount,
    required double percent,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$amount/mo',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth * percent * _animation.value,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
