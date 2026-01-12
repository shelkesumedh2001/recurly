import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../providers/analytics_providers.dart';
import '../../theme/app_theme.dart';

class CategoryPieChart extends ConsumerStatefulWidget {
  const CategoryPieChart({super.key});

  @override
  ConsumerState<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends ConsumerState<CategoryPieChart>
    with SingleTickerProviderStateMixin {
  int _touchedIndex = -1;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Longer, smoother animation
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo, // Smooth exponential ease out
    );
    // Start animation with a tiny delay for better perception
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categorySpend = ref.watch(categorySpendProvider);

    if (categorySpend.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final total = categorySpend.values.fold<double>(0, (sum, val) => sum + val);
    final sortedEntries = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: [
            // Pie Chart - constrained to prevent overflow
            Center(
              child: SizedBox(
                width: 240, // Fixed width to constrain the circle
                height: 240, // Fixed height (square)
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 1, // Minimal space for smoothness
                    centerSpaceRadius: 45,
                    startDegreeOffset: -90, // Start from top
                    sections: _showingSections(
                      theme,
                      sortedEntries,
                      total,
                      _animation.value,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Legend with animation
            Opacity(
              opacity: _animation.value,
              child: Wrap(
                spacing: 20,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: sortedEntries.asMap().entries.map((mapEntry) {
                  final index = mapEntry.key;
                  final data = mapEntry.value;
                  final percentage = (data.value / total * 100).toStringAsFixed(1);
                  final color = _getCategoryColorByIndex(index);

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getCategoryGradientByIndex(index),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${data.key.displayName} ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  List<PieChartSectionData> _showingSections(
    ThemeData theme,
    List<MapEntry<SubscriptionCategory, double>> sortedEntries,
    double total,
    double animationValue,
  ) {
    return List.generate(sortedEntries.length, (i) {
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 65.0 : 60.0; // Proper size for 240x240 container
      final entry = sortedEntries[i];

      // Staggered animation - each segment starts slightly after the previous one
      final segmentDelay = i * 0.08; // 80ms delay per segment
      final segmentAnimationValue = (animationValue - segmentDelay).clamp(0.0, 1.0);

      // Smooth ease for each segment
      final easedValue = Curves.easeOutCubic.transform(segmentAnimationValue);
      final animatedValue = entry.value * easedValue;

      return PieChartSectionData(
        value: animatedValue,
        title: '',
        radius: radius,
        gradient: LinearGradient(
          colors: _getCategoryGradientByIndex(i),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderSide: BorderSide(
          color: theme.colorScheme.surface.withValues(alpha: 0.3),
          width: 1.5, // Thinner, more subtle borders
        ),
      );
    });
  }

  Color _getCategoryColorByIndex(int index) {
    return AppTheme.getCategoryColor(index);
  }

  List<Color> _getCategoryGradientByIndex(int index) {
    return AppTheme.getCategoryGradient(index);
  }
}
