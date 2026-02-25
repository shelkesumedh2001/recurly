import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/subscription.dart';
import '../../providers/analytics_providers.dart';
import '../../providers/currency_providers.dart';
import '../../theme/app_theme.dart';

class PriceChangesSection extends ConsumerStatefulWidget {
  const PriceChangesSection({super.key});

  @override
  ConsumerState<PriceChangesSection> createState() => _PriceChangesSectionState();
}

class _PriceChangesSectionState extends ConsumerState<PriceChangesSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
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
    final theme = Theme.of(context);
    final subsWithChanges = ref.watch(subscriptionsWithPriceChangesProvider);
    final totalImpact = ref.watch(totalPriceChangeImpactProvider);
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final exchangeRates = ref.watch(exchangeRatesProvider).value;

    if (subsWithChanges.isEmpty) return const SizedBox.shrink();

    final isIncrease = totalImpact > 0;
    final impactConverted = currencyService.convert(
      amount: totalImpact.abs(),
      from: displayCurrency, // impact is already approximated in original currencies
      to: displayCurrency,
      rates: exchangeRates,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isIncrease ? AppTheme.expenseColor : AppTheme.incomeColor)
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isIncrease ? AppTheme.expenseColor : AppTheme.incomeColor)
                  .withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isIncrease ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: isIncrease ? AppTheme.expenseColor : AppTheme.incomeColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${subsWithChanges.length} subscription${subsWithChanges.length == 1 ? '' : 's'} had price changes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isIncrease ? '+' : '-'}${currencyService.formatAmount(impactConverted, displayCurrency)}/mo impact',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isIncrease ? AppTheme.expenseColor : AppTheme.incomeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Price change cards
        ...subsWithChanges.asMap().entries.map((entry) {
          final index = entry.key;
          final sub = entry.value;
          return _buildAnimatedCard(
            index: index,
            child: _PriceChangeCard(subscription: sub),
          );
        }),
      ],
    );
  }

  Widget _buildAnimatedCard({required int index, required Widget child}) {
    final delay = (index * 0.12).clamp(0.0, 0.6);
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final progress = ((_animationController.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(progress);
        return Transform.translate(
          offset: Offset(0, 16 * (1 - curved)),
          child: Opacity(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }
}

class _PriceChangeCard extends StatelessWidget {
  const _PriceChangeCard({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastChange = subscription.lastPriceChange!;
    final oldPrice = (lastChange['price'] as num).toDouble();
    final changeCurrency = lastChange['currency'] as String? ?? subscription.currency;
    final changeDate = DateTime.parse(lastChange['date'] as String);
    final changeAmount = subscription.price - oldPrice;
    final changePercent = subscription.lastPriceChangePercent;
    final isIncrease = changeAmount > 0;

    final color = isIncrease ? AppTheme.expenseColor : AppTheme.incomeColor;

    // Format old price with its currency symbol
    final symbol = subscription.currencySymbol;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Logo or initial
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: color,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$symbol${oldPrice.toStringAsFixed(2)} → $symbol${subscription.price.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(changeDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncrease ? '+' : ''}$symbol${changeAmount.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '${isIncrease ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
