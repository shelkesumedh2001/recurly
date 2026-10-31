import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../providers/analytics_providers.dart';
import '../../providers/currency_providers.dart';
import '../../theme/app_tokens.dart';
import '../../utils/spend_history.dart';
import '../../utils/stagger.dart';

/// What you were actually billed each month over the past year.
///
/// "All" stacks the months by category; picking a category filters the bars
/// to just that category. Colours follow the category (same as the donut),
/// so filtering never repaints anything.
class SpendHistoryChart extends ConsumerStatefulWidget {
  const SpendHistoryChart({super.key});

  @override
  ConsumerState<SpendHistoryChart> createState() => _SpendHistoryChartState();
}

class _SpendHistoryChartState extends ConsumerState<SpendHistoryChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1100),
    vsync: this,
  );

  /// Null = all categories (stacked).
  SubscriptionCategory? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final history = ref.watch(spendHistoryProvider);
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    String money(double v) => currencyService.formatAmount(v, displayCurrency);

    // Categories that billed anything in the window, in fixed enum order.
    final present = SubscriptionCategory.values
        .where((c) => history.any((m) => (m.byCategory[c] ?? 0) > 0))
        .toList();

    if (history.isEmpty || present.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No bills in the past year yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    // A filtered category can vanish (e.g. its only sub was deleted).
    final filter = present.contains(_filter) ? _filter : null;
    final stacked = filter == null && present.length > 1;

    final amounts = [for (final m in history) m.amountFor(filter)];
    final windowTotal = amounts.fold<double>(0, (a, b) => a + b);
    final firstActive = amounts.indexWhere((a) => a > 0);
    final activeMonths = firstActive < 0 ? 1 : amounts.length - firstActive;
    final average = windowTotal / activeMonths;
    final maxAmount = amounts.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxAmount > 0 ? maxAmount * 1.2 : 1.0;

    final surface = theme.colorScheme.surfaceContainer;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters: one row, above the chart.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final c in present)
                _FilterChip(
                  label: c.displayName,
                  dotColor: tokens.chartColor(c.index),
                  selected: filter == c,
                  onTap: () => setState(() => _filter = c),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Headline numbers for the current filter.
        Text(
          money(windowTotal),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: kTabularFigures,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Past 12 months · ${money(average)} a month on average',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 20),

        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => AspectRatio(
            aspectRatio: 1.6,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipBorderRadius: BorderRadius.circular(10),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    // Opaque, and wide enough for "Category  £0.00" lines.
                    maxContentWidth: 220,
                    getTooltipColor: (_) => theme
                        .colorScheme.surfaceContainerHighest
                        .withValues(alpha: 1),
                    tooltipBorder: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        _tooltip(
                      theme,
                      history[groupIndex],
                      filter,
                      stacked,
                      money,
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        // Label every other month, always including this one.
                        if (i < 0 ||
                            i >= history.length ||
                            (history.length - 1 - i).isOdd) {
                          return const SizedBox.shrink();
                        }
                        final m = history[i];
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            DateFormat('MMM').format(DateTime(m.year, m.month)),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < history.length; i++)
                    _group(
                      i,
                      history[i],
                      filter,
                      stacked,
                      present,
                      staggeredProgress(
                        _controller.value,
                        i,
                        history.length,
                        stagger: 0.04,
                      ),
                      tokens,
                      surface,
                    ),
                ],
              ),
            ),
          ),
        ),

        // Legend: always present when more than one series is stacked.
        if (stacked) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final c in present)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: tokens.chartColor(c.index),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c.displayName,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  BarChartGroupData _group(
    int x,
    MonthSpend month,
    SubscriptionCategory? filter,
    bool stacked,
    List<SubscriptionCategory> present,
    double grow,
    AppTokens tokens,
    Color surface,
  ) {
    const radius = BorderRadius.vertical(top: Radius.circular(4));
    final total = month.amountFor(filter);

    if (!stacked) {
      final color = tokens.chartColor((filter ?? present.single).index);
      return BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: total * grow,
            color: color,
            width: 14,
            borderRadius: radius,
          ),
        ],
      );
    }

    // Stack bottom-up in fixed category order; a thin surface-coloured
    // border separates the segments.
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (final c in present) {
      final v = (month.byCategory[c] ?? 0) * grow;
      if (v <= 0) continue;
      items.add(
        BarChartRodStackItem(
          from,
          from + v,
          tokens.chartColor(c.index),
          BorderSide(color: surface),
        ),
      );
      from += v;
    }
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: from,
          color: Colors.transparent,
          rodStackItems: items,
          width: 14,
          borderRadius: radius,
        ),
      ],
    );
  }

  BarTooltipItem _tooltip(
    ThemeData theme,
    MonthSpend month,
    SubscriptionCategory? filter,
    bool stacked,
    String Function(double) money,
  ) {
    final label = DateFormat('MMMM yyyy').format(DateTime(month.year, month.month));
    final head = month.isCurrentMonth ? '$label (incl. bills still due)\n' : '$label\n';
    final headStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      fontWeight: FontWeight.w600,
    );
    final valueStyle = theme.textTheme.titleSmall!.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      fontFeatures: kTabularFigures,
    );
    final lineStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
      fontFeatures: kTabularFigures,
    );

    final breakdown = stacked
        ? (month.byCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
        : const <MapEntry<SubscriptionCategory, double>>[];

    return BarTooltipItem(
      head,
      headStyle,
      textAlign: TextAlign.left,
      children: [
        TextSpan(text: money(month.amountFor(filter)), style: valueStyle),
        for (final e in breakdown)
          TextSpan(
            text: '\n${e.key.displayName}  ${money(e.value)}',
            style: lineStyle,
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        avatar: dotColor == null
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
      ),
    );
  }
}
