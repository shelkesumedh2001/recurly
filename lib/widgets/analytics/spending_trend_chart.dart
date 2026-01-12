import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/analytics_providers.dart';

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

    if (trendData.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final monthName = DateFormat('MMM').format(DateTime(0, trendData[groupIndex].month));
                return BarTooltipItem(
                  '$monthName\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: '\$${rod.toY.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
            horizontalInterval: maxY / 4,
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
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  ),
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
