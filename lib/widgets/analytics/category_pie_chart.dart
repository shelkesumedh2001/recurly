import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../providers/analytics_providers.dart';
import '../../theme/app_theme.dart';
import 'category_detail_sheet.dart';

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
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    );
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
            // Pie Chart with tap support
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
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

                            // Handle tap to show detail sheet
                            if (event is FlTapUpEvent &&
                                pieTouchResponse != null &&
                                pieTouchResponse.touchedSection != null) {
                              final tappedIndex = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                              if (tappedIndex >= 0 && tappedIndex < sortedEntries.length) {
                                final entry = sortedEntries[tappedIndex];
                                showCategoryDetailSheet(
                                  context,
                                  category: entry.key,
                                  categoryIndex: tappedIndex,
                                  totalAmount: entry.value,
                                );
                              }
                            }
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        startDegreeOffset: -90,
                        sections: _showingSections(
                          theme,
                          sortedEntries,
                          total,
                          _animation.value,
                        ),
                      ),
                    ),
                    // Center total
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${total.toStringAsFixed(0)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/month',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Tap hint
            Opacity(
              opacity: _animation.value,
              child: Text(
                'Tap a segment to see details',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend with animation
            Opacity(
              opacity: _animation.value,
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: sortedEntries.asMap().entries.map((mapEntry) {
                  final index = mapEntry.key;
                  final data = mapEntry.value;
                  final percentage = (data.value / total * 100).toStringAsFixed(1);
                  final color = _getCategoryColorByIndex(index);
                  final isTouched = index == _touchedIndex;

                  return GestureDetector(
                    onTap: () {
                      showCategoryDetailSheet(
                        context,
                        category: data.key,
                        categoryIndex: index,
                        totalAmount: data.value,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: isTouched ? 12 : 8,
                        vertical: isTouched ? 8 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: isTouched
                            ? color.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
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
                          const SizedBox(width: 8),
                          Text(
                            data.key.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isTouched ? FontWeight.w700 : FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$percentage%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
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
      final radius = isTouched ? 70.0 : 60.0;
      final entry = sortedEntries[i];

      // Staggered animation
      final segmentDelay = i * 0.08;
      final segmentAnimationValue = (animationValue - segmentDelay).clamp(0.0, 1.0);
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
          color: theme.colorScheme.surface,
          width: isTouched ? 3 : 2,
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
