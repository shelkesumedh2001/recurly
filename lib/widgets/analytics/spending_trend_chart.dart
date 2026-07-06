import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/analytics_providers.dart';
import '../../providers/currency_providers.dart';
import '../../theme/app_tokens.dart';

class SpendingTrendChart extends ConsumerStatefulWidget {
  const SpendingTrendChart({super.key});

  @override
  ConsumerState<SpendingTrendChart> createState() => _SpendingTrendChartState();
}

class _SpendingTrendChartState extends ConsumerState<SpendingTrendChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
    final theme = Theme.of(context);
    final trendData = ref.watch(spendingTrendProvider);
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    if (trendData.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    final maxSpend = trendData.fold<double>(0, (max, item) => item.amount > max ? item.amount : max);
    // Add 20% buffer to Y-axis
    final maxY = maxSpend * 1.2;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return AspectRatio(
          aspectRatio: 1.5,
          child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tooltipMargin: 8,
              getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
              tooltipBorder: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final monthName = DateFormat('MMM').format(DateTime(0, trendData[groupIndex].month));
                return BarTooltipItem(
                  '$monthName\n',
                  theme.textTheme.labelMedium!.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: currencyService.formatAmount(rod.toY, displayCurrency),
                      style: theme.textTheme.titleSmall!.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= trendData.length) return const SizedBox.shrink();
                  final data = trendData[value.toInt()];
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      DateFormat('MMM').format(DateTime(0, data.month)),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: trendData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            // Animate each bar with a slight delay based on index
            final barAnimation = Curves.easeOutCubic.transform(
              (_animation.value - (index * 0.1)).clamp(0.0, 1.0),
            );
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data.amount * barAnimation,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.55),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
        ),
          ),
        );
      },
    );
  }
}
