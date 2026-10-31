import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/providers/analytics_providers.dart';
import 'package:recurly/utils/stagger.dart';
import 'package:recurly/widgets/analytics/spending_trend_chart.dart';

/// Regression for the Oct 2026 user report: a flat £5/month projection
/// rendered each later month smaller (£5 → … → £4.38) because the staggered
/// bar animation never let later bars finish.
void main() {
  group('staggeredProgress', () {
    test('every bar is full when the animation completes', () {
      for (final count in [1, 2, 6, 12]) {
        for (var i = 0; i < count; i++) {
          expect(
            staggeredProgress(1, i, count),
            1.0,
            reason: 'bar $i of $count',
          );
        }
      }
    });

    test('every bar starts empty', () {
      for (var i = 0; i < 6; i++) {
        expect(staggeredProgress(0, i, 6), 0);
      }
    });

    test('later bars trail earlier ones mid-animation', () {
      final first = staggeredProgress(0.3, 0, 6);
      final last = staggeredProgress(0.3, 5, 6);
      expect(first, greaterThan(last));
    });
  });

  testWidgets('flat monthly projection renders equal bars once settled',
      (tester) async {
    final flat = [
      for (var m = 10; m < 16; m++)
        MonthlySpendingData((m - 1) % 12 + 1, 2026 + (m - 1) ~/ 12, 5),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [spendingTrendProvider.overrideWithValue(flat)],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 360, child: SpendingTrendChart()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final heights = [
      for (final g in chart.data.barGroups) g.barRods.single.toY,
    ];
    expect(heights, List.filled(6, 5));
  });
}
