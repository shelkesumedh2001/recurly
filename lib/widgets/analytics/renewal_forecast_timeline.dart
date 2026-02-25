import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/analytics_providers.dart';
import '../../providers/currency_providers.dart';
import '../../theme/app_theme.dart';

class RenewalForecastTimeline extends ConsumerStatefulWidget {
  const RenewalForecastTimeline({super.key});

  @override
  ConsumerState<RenewalForecastTimeline> createState() =>
      _RenewalForecastTimelineState();
}

class _RenewalForecastTimelineState
    extends ConsumerState<RenewalForecastTimeline>
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
    final renewals = ref.watch(upcomingRenewalsProvider);
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    if (renewals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            'No renewals in the next 30 days',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    // Group renewals by date
    final grouped = <DateTime, List<UpcomingRenewal>>{};
    for (final r in renewals) {
      final dateKey = DateTime(r.date.year, r.date.month, r.date.day);
      grouped.putIfAbsent(dateKey, () => []).add(r);
    }
    final sortedDates = grouped.keys.toList()..sort();

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final dayRenewals = grouped[date]!;
          final isToday = _isToday(date);

          // Staggered animation
          final delay = (index * 0.08).clamp(0.0, 0.5);
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, _) {
              final progress = ((_animationController.value - delay) /
                      (1.0 - delay))
                  .clamp(0.0, 1.0);
              final curved = Curves.easeOutCubic.transform(progress);

              return Opacity(
                opacity: curved,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - curved)),
                  child: _buildDateColumn(
                    theme,
                    date,
                    dayRenewals,
                    isToday,
                    currencyService,
                    displayCurrency,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildDateColumn(
    ThemeData theme,
    DateTime date,
    List<UpcomingRenewal> renewals,
    bool isToday,
    dynamic currencyService,
    String displayCurrency,
  ) {
    final dayTotal = renewals.fold<double>(
        0, (sum, r) => sum + r.convertedAmount);

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday
            ? AppTheme.primaryCoral.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? AppTheme.primaryCoral.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Row(
            children: [
              if (isToday)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCoral,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Text(
                  isToday ? 'Today' : DateFormat('MMM d').format(date),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isToday
                        ? AppTheme.primaryCoral
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          Text(
            isToday
                ? DateFormat('EEE').format(date)
                : DateFormat('EEE').format(date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
          const Spacer(),
          // Subscription names (max 2 visible)
          ...renewals.take(2).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  r.subscription.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
          if (renewals.length > 2)
            Text(
              '+${renewals.length - 2} more',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          const SizedBox(height: 4),
          // Total for the day
          Text(
            currencyService.formatAmount(dayTotal, displayCurrency),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.expenseColor,
            ),
          ),
        ],
      ),
    );
  }
}
