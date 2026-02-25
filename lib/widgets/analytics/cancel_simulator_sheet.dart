import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subscription.dart';
import '../../providers/currency_providers.dart';
import '../../theme/app_theme.dart';

class CancelSimulatorSheet extends ConsumerStatefulWidget {
  const CancelSimulatorSheet({super.key, required this.subscription});

  final Subscription subscription;

  @override
  ConsumerState<CancelSimulatorSheet> createState() => _CancelSimulatorSheetState();
}

class _CancelSimulatorSheetState extends ConsumerState<CancelSimulatorSheet>
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
    final sub = widget.subscription;
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final totalMonthly = ref.watch(convertedTotalSpendProvider);

    // Convert to display currency
    final monthlyAmount = currencyService.convert(
      amount: sub.monthlyEquivalent,
      from: sub.currency,
      to: displayCurrency,
      rates: ref.watch(exchangeRatesProvider).value,
    );
    final yearlyAmount = monthlyAmount * 12;
    final fiveYearAmount = monthlyAmount * 60;
    final dailyAmount = monthlyAmount / 30;
    final percentOfTotal = totalMonthly > 0 ? (monthlyAmount / totalMonthly * 100) : 0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header with sub info
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.expenseColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: sub.logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            sub.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                sub.name[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.expenseColor,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            sub.name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.expenseColor,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'If You Cancel',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        sub.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  sub.formattedPrice,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.expenseColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Savings cards with staggered animation
            _buildAnimatedCard(
              index: 0,
              child: _buildSavingsCard(
                theme,
                label: 'Monthly Savings',
                amount: currencyService.formatAmount(monthlyAmount, displayCurrency),
                icon: Icons.calendar_month_rounded,
              ),
            ),
            const SizedBox(height: 10),
            _buildAnimatedCard(
              index: 1,
              child: _buildSavingsCard(
                theme,
                label: 'Yearly Savings',
                amount: currencyService.formatAmount(yearlyAmount, displayCurrency),
                icon: Icons.date_range_rounded,
              ),
            ),
            const SizedBox(height: 10),
            _buildAnimatedCard(
              index: 2,
              child: _buildSavingsCard(
                theme,
                label: '5-Year Savings',
                amount: currencyService.formatAmount(fiveYearAmount, displayCurrency),
                icon: Icons.savings_rounded,
              ),
            ),

            const SizedBox(height: 16),

            // Daily equivalent and impact
            _buildAnimatedCard(
              index: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "That's ${currencyService.formatAmount(dailyAmount, displayCurrency)} per day",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is ${percentOfTotal.toStringAsFixed(1)}% of your total monthly spend',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({required int index, required Widget child}) {
    final delay = index * 0.15;
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final progress = ((_animationController.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(progress);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - curved)),
          child: Opacity(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildSavingsCard(
    ThemeData theme, {
    required String label,
    required String amount,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.incomeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.incomeColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.incomeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.incomeColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            amount,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.incomeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Show the cancel simulator sheet
void showCancelSimulatorSheet(BuildContext context, Subscription subscription) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: CancelSimulatorSheet(subscription: subscription),
    ),
  );
}
