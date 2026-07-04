import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/budget.dart';
import '../../providers/budget_providers.dart';
import '../../providers/currency_providers.dart';
import '../../providers/navigation_providers.dart';
import '../../services/currency_service.dart';
import '../../theme/app_tokens.dart';

class BudgetGauge extends ConsumerStatefulWidget {
  const BudgetGauge({super.key});

  @override
  ConsumerState<BudgetGauge> createState() => _BudgetGaugeState();
}

class _BudgetGaugeState extends ConsumerState<BudgetGauge>
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
    // Under IndexedStack the gauge builds (and its arc fills) before the
    // Analytics tab is ever shown — replay the fill each time it's opened.
    ref.listenManual(selectedTabProvider, (previous, next) {
      if (next == analyticsTabIndex && previous != analyticsTabIndex) {
        _animationController.forward(from: 0);
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
    final usage = ref.watch(budgetUsageProvider);
    if (usage == null) return const SizedBox.shrink();

    final settings = ref.watch(budgetSettingsProvider);
    final status = ref.watch(budgetStatusProvider);
    final remaining = ref.watch(remainingBudgetProvider);
    final totalSpend = ref.watch(convertedTotalSpendProvider);
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    final budget = settings.overallMonthlyBudget ?? 0;
    final forecast = ref.watch(budgetForecastProvider);
    final clampedUsage = usage.clamp(0.0, 1.0);

    Color gaugeColor;
    switch (status) {
      case BudgetStatus.safe:
        gaugeColor = AppTokens.of(context).success;
      case BudgetStatus.warning:
        gaugeColor = const Color(0xFFFFB366); // amber
      case BudgetStatus.exceeded:
        gaugeColor = AppTokens.of(context).danger;
      case BudgetStatus.noBudget:
        return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 28),
        Text(
          'Budget',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
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
                  SizedBox(
                    width: 220,
                    height: 160,
                    child: CustomPaint(
                      painter: _GaugeArcPainter(
                        progress: clampedUsage * _animation.value,
                        color: gaugeColor,
                        trackColor: theme.colorScheme.surfaceContainerHighest,
                        warningThreshold: settings.warningThreshold,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: Text(
                            '${(usage * 100 * _animation.value).toInt()}%',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: gaugeColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${currencyService.formatAmount(totalSpend, displayCurrency)} / ${currencyService.formatAmount(budget, displayCurrency)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (remaining != null && remaining >= 0)
                    Text(
                      '${currencyService.formatAmount(remaining, displayCurrency)} remaining',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: gaugeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else if (remaining != null)
                    Text(
                      'Over budget by ${currencyService.formatAmount(remaining.abs(), displayCurrency)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTokens.of(context).danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ..._buildForecast(
                    context,
                    theme,
                    forecast,
                    budget,
                    currencyService,
                    displayCurrency,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Cash-flow forecast: what has billed this month, what's still coming,
  /// and whether the projected month-end total busts the cap.
  List<Widget> _buildForecast(
    BuildContext context,
    ThemeData theme,
    BudgetForecast? forecast,
    double budget,
    CurrencyService currencyService,
    String displayCurrency,
  ) {
    if (forecast == null) return const [];
    // Nothing scheduled and nothing billed — the run-rate readout above
    // already says everything; don't show an empty cash breakdown.
    if (forecast.billedSoFar == 0 && forecast.upcomingCount == 0) {
      return const [];
    }

    final tokens = AppTokens.of(context);
    final overBy = forecast.projected - budget;
    final statusColor = overBy > 0 ? tokens.danger : tokens.success;

    String fmt(double v) => currencyService.formatAmount(v, displayCurrency);

    // "Projected …" while charges are still pending, "Billed …" once the
    // month is fully charged. Verdict compares this month's real cash to
    // the budget (a lumpy annual renewal will read as a heavy month).
    final lead = forecast.upcomingCount > 0
        ? 'Projected ${fmt(forecast.projected)} this month'
        : 'Billed ${fmt(forecast.projected)} this month';
    final String verdict;
    if (overBy > 0) {
      verdict = '$lead · ${fmt(overBy)} over budget';
    } else if (overBy < 0) {
      verdict = '$lead · ${fmt(-overBy)} under budget';
    } else {
      verdict = '$lead · on budget';
    }

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );

    return [
      const SizedBox(height: 16),
      Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      const SizedBox(height: 10),
      row('Billed this month', fmt(forecast.billedSoFar)),
      if (forecast.upcomingCount > 0)
        row(
          'Still to renew (${forecast.upcomingCount})',
          fmt(forecast.upcoming),
        ),
      const SizedBox(height: 8),
      Text(
        verdict,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
  }
}

class _GaugeArcPainter extends CustomPainter {
  _GaugeArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.warningThreshold,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double warningThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = min(size.width / 2, size.height) - 12;

    const sweepAngle = pi * 1.5; // 270 degrees
    const startAngle = pi * 0.75; // start from lower-left

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Progress
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
