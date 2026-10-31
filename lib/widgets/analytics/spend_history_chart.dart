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

/// Fill opacity for estimated (future) bars. Billed bars are solid.
const double _kEstimateFill = 0.28;

/// Dash pattern for the outline of estimated bars and their key swatch.
const List<int> _kEstimateDash = [3, 2];

/// Spend over time: the past year as billed, then an estimate for the
/// coming months.
///
/// Past bars are solid (facts). Future bars are faint with a dashed outline
/// and sit after a gap, because they only reflect today's subscriptions and
/// will move as subs are added or cancelled. "All" stacks by category;
/// a category chip filters to it. Colours follow the category (same as the
/// donut), so filtering never repaints anything.
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
    final timeline = ref.watch(spendTimelineProvider);
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    String money(double v) => currencyService.formatAmount(v, displayCurrency);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    // Categories with any bill in the window, in fixed enum order.
    final present = SubscriptionCategory.values
        .where((c) => timeline.any((m) => (m.byCategory[c] ?? 0) > 0))
        .toList();

    if (timeline.isEmpty || present.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No bills to show yet',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ),
      );
    }

    // A filtered category can vanish (e.g. its only sub was deleted).
    final filter = present.contains(_filter) ? _filter : null;
    final stacked = filter == null && present.length > 1;

    final billed = timeline.where((m) => !m.isEstimate).toList();
    final estimated = timeline.where((m) => m.isEstimate).toList();

    // Facts: billed total and average over the months with any bills.
    final billedAmounts = [for (final m in billed) m.amountFor(filter)];
    final billedTotal = billedAmounts.fold<double>(0, (a, b) => a + b);
    final firstActive = billedAmounts.indexWhere((a) => a > 0);
    final activeMonths =
        firstActive < 0 ? 1 : billedAmounts.length - firstActive;
    final billedAverage = billedTotal / activeMonths;

    // Estimate: kept visibly separate from the facts.
    final estimateTotal =
        estimated.fold<double>(0, (a, m) => a + m.amountFor(filter));

    final spikes = findSpikes(timeline, filter: filter);

    // Bar slots: billed months, one empty slot as the "today" gap, then the
    // estimated months. A null slot is the gap.
    final slots = <MonthSpend?>[
      ...billed,
      if (estimated.isNotEmpty) null,
      ...estimated,
    ];
    final currentSlot = slots.indexWhere((m) => m?.isCurrentMonth ?? false);

    final maxAmount = timeline.fold<double>(
      0,
      (a, m) => m.amountFor(filter) > a ? m.amountFor(filter) : a,
    );
    final maxY = maxAmount > 0 ? maxAmount * 1.2 : 1.0;

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

        // Headline: the fact.
        Text(
          money(billedTotal),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: kTabularFigures,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Billed in the past ${billed.length} months · '
          '${money(billedAverage)} a month on average',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        if (estimated.isNotEmpty) ...[
          const SizedBox(height: 4),
          // The estimate, worded as one.
          Text(
            'Next ${estimated.length} months: about ${money(estimateTotal)} '
            'if your subscriptions stay as they are',
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Key for billed vs estimate.
        Row(
          children: [
            _KeySwatch(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Billed',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
            const SizedBox(width: 16),
            _KeySwatch(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              estimate: true,
            ),
            const SizedBox(width: 6),
            Text(
              'Estimate',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ),
        const SizedBox(height: 8),

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
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final m = slots[groupIndex];
                      if (m == null) return null;
                      return _tooltip(theme, m, filter, stacked, money);
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= slots.length) {
                          return const SizedBox.shrink();
                        }
                        final m = slots[i];
                        // Every third month, counted from this month (the
                        // gap slot shifts the future side by one).
                        final steps = i <= currentSlot
                            ? currentSlot - i
                            : i - currentSlot - 1;
                        if (m == null || steps % 3 != 0) {
                          return const SizedBox.shrink();
                        }
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
                  for (var i = 0; i < slots.length; i++)
                    if (slots[i] == null)
                      BarChartGroupData(x: i)
                    else
                      _group(
                        i,
                        slots[i]!,
                        filter,
                        stacked,
                        present,
                        staggeredProgress(
                          _controller.value,
                          i,
                          slots.length,
                          stagger: 0.03,
                        ),
                        tokens,
                        theme,
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

        // Why a coming month is bigger, in words a bar can't give.
        for (final spike in spikes.take(2)) ...[
          const SizedBox(height: 12),
          _SpikeNote(spike: spike, money: money),
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
    ThemeData theme,
  ) {
    const radius = BorderRadius.vertical(top: Radius.circular(4));
    const width = 9.0;
    final estimate = month.isEstimate;
    Color fill(Color c) => estimate ? c.withValues(alpha: _kEstimateFill) : c;

    if (!stacked) {
      final color = tokens.chartColor((filter ?? present.single).index);
      return BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: month.amountFor(filter) * grow,
            color: fill(color),
            width: width,
            borderRadius: radius,
            borderSide: estimate ? BorderSide(color: color) : BorderSide.none,
            borderDashArray: estimate ? _kEstimateDash : null,
          ),
        ],
      );
    }

    // Stack bottom-up in fixed category order; a thin surface-coloured
    // border separates the segments.
    final surface = theme.colorScheme.surfaceContainer;
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (final c in present) {
      final v = (month.byCategory[c] ?? 0) * grow;
      if (v <= 0) continue;
      items.add(
        BarChartRodStackItem(
          from,
          from + v,
          fill(tokens.chartColor(c.index)),
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
          width: width,
          borderRadius: radius,
          borderSide: estimate
              ? BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                )
              : BorderSide.none,
          borderDashArray: estimate ? _kEstimateDash : null,
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
    final label =
        DateFormat('MMMM yyyy').format(DateTime(month.year, month.month));
    final head = switch (month.period) {
      SpendPeriod.past => '$label\n',
      SpendPeriod.current => '$label · incl. bills still due\n',
      SpendPeriod.future => '$label · estimate\n',
    };
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
    final amount = money(month.amountFor(filter));

    return BarTooltipItem(
      head,
      headStyle,
      textAlign: TextAlign.left,
      children: [
        TextSpan(
          text: month.isEstimate ? 'about $amount' : amount,
          style: valueStyle,
        ),
        for (final e in breakdown)
          TextSpan(
            text: '\n${e.key.displayName}  ${money(e.value)}',
            style: lineStyle,
          ),
        if (month.isEstimate)
          TextSpan(
            text: '\nBased on your subscriptions today',
            style: lineStyle.copyWith(fontStyle: FontStyle.italic),
          ),
      ],
    );
  }
}

/// "January will likely be higher: about £148 (usually £54).
///  Amazon Prime renews."
class _SpikeNote extends StatelessWidget {
  const _SpikeNote({required this.spike, required this.money});

  final SpendSpike spike;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final month = DateFormat('MMMM').format(
      DateTime(spike.month.year, spike.month.month),
    );
    final names = spike.causes.map((b) => b.name).join(' and ');
    final verb = spike.causes.length == 1 ? 'renews' : 'renew';
    final ink = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.trending_up_rounded, size: 18, color: ink),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$month will likely be higher: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: 'about ${money(spike.amount)} '
                      '(usually ${money(spike.usual)}). $names $verb.',
                ),
              ],
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: ink),
          ),
        ),
      ],
    );
  }
}

/// Key swatch: solid for billed, faint with a dashed outline for estimate —
/// the same treatment the bars get.
class _KeySwatch extends StatelessWidget {
  const _KeySwatch({required this.color, this.estimate = false});

  final Color color;
  final bool estimate;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 10),
      painter: _SwatchPainter(color: color, estimate: estimate),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter({required this.color, required this.estimate});

  final Color color;
  final bool estimate;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(2),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = estimate ? color.withValues(alpha: _kEstimateFill) : color,
    );
    if (!estimate) return;

    // Dashed outline, walking the rectangle's perimeter.
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(rect.deflate(0.5));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      var on = true;
      var i = 0;
      while (d < metric.length) {
        final len = _kEstimateDash[i % _kEstimateDash.length].toDouble();
        if (on) canvas.drawPath(metric.extractPath(d, d + len), stroke);
        d += len;
        on = !on;
        i++;
      }
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.estimate != estimate;
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
