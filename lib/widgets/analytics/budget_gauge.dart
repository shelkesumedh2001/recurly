import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/budget.dart';
import '../../providers/budget_providers.dart';
import '../../providers/currency_providers.dart';
import '../../theme/app_theme.dart';

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
    final clampedUsage = usage.clamp(0.0, 1.0);

    Color gaugeColor;
    switch (status) {
      case BudgetStatus.safe:
        gaugeColor = AppTheme.incomeColor;
      case BudgetStatus.warning:
        gaugeColor = const Color(0xFFFFB366); // amber
      case BudgetStatus.exceeded:
        gaugeColor = AppTheme.expenseColor;
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
                        color: AppTheme.expenseColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
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
