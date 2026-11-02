import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/custom_category.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/providers/analytics_providers.dart';
import 'package:recurly/utils/spend_history.dart';
import 'package:recurly/widgets/analytics/spend_history_chart.dart';

final DateTime _now = DateTime(2026, 10, 20);

Subscription _sub({
  String id = 's',
  double price = 5,
  String currency = 'GBP',
  BillingCycle cycle = BillingCycle.monthly,
  SubscriptionCategory category = SubscriptionCategory.entertainment,
  required DateTime firstBill,
  List<Map<String, dynamic>>? priceHistory,
}) =>
    Subscription(
      id: id,
      name: id,
      price: price,
      currency: currency,
      billingCycle: cycle,
      category: category,
      firstBillDate: firstBill,
      createdAt: firstBill,
      priceHistory: priceHistory,
    );

double _identity(double amount, String from) => amount;

List<double> _totals(List<MonthSpend> h, [SubscriptionCategory? c]) =>
    [for (final m in h) m.amountFor(c == null ? null : _u(c))];

UnifiedCategory _u(SubscriptionCategory c) => UnifiedCategory.fromEnum(c);

void main() {
  group('computeSpendHistory', () {
    test('12 months, oldest first, ending with the current month', () {
      final h = computeSpendHistory(
        subscriptions: const [],
        now: _now,
        convert: _identity,
      );
      expect(h, hasLength(12));
      expect((h.first.year, h.first.month), (2025, 11));
      expect((h.last.year, h.last.month), (2026, 10));
      expect(h.last.isCurrentMonth, isTrue);
      expect(h.where((m) => m.isCurrentMonth), hasLength(1));
    });

    test('monthly sub bills every month from its first bill, not before', () {
      final h = computeSpendHistory(
        subscriptions: [_sub(firstBill: DateTime(2026, 7, 3))],
        now: _now,
        convert: _identity,
      );
      expect(_totals(h), [0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 5, 5]);
    });

    test('current month includes a bill still due later this month', () {
      final h = computeSpendHistory(
        subscriptions: [_sub(firstBill: DateTime(2026, 9, 28))],
        now: _now, // Oct 20; the Oct 28 bill is still due
        convert: _identity,
      );
      expect(h.last.total, 5);
    });

    test('yearly sub spikes only in its renewal month', () {
      final h = computeSpendHistory(
        subscriptions: [
          _sub(
            price: 60,
            cycle: BillingCycle.yearly,
            firstBill: DateTime(2024, 3, 10),
          ),
        ],
        now: _now,
        convert: _identity,
      );
      expect(_totals(h), [0, 0, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0]);
    });

    test('weekly sub bills 4 or 5 times depending on the month', () {
      final h = computeSpendHistory(
        // Thursdays from 1 Jan 2026.
        subscriptions: [
          _sub(price: 1, cycle: BillingCycle.weekly, firstBill: DateTime(2026, 1, 1)),
        ],
        now: _now,
        convert: _identity,
      );
      // Jan 2026 has 5 Thursdays, Feb 4, Oct 5.
      expect(h[2].total, 5); // Jan
      expect(h[3].total, 4); // Feb
      expect(h.last.total, 5); // Oct
    });

    test('bills are priced at what they cost on the day', () {
      final h = computeSpendHistory(
        subscriptions: [
          _sub(
            price: 7,
            firstBill: DateTime(2026, 5, 15),
            priceHistory: [
              {'price': 5.0, 'currency': 'GBP', 'date': '2026-07-01T09:00:00.000'},
              {'price': 6.0, 'currency': 'GBP', 'date': '2026-09-01T09:00:00.000'},
            ],
          ),
        ],
        now: _now,
        convert: _identity,
      );
      // May/Jun at 5, Jul/Aug at 6, Sep/Oct at the current 7.
      expect(_totals(h).sublist(6), [5, 5, 6, 6, 7, 7]);
    });

    test('splits by category and filters by one', () {
      final h = computeSpendHistory(
        subscriptions: [
          _sub(id: 'a', price: 5, firstBill: DateTime(2026, 9, 1)),
          _sub(
            id: 'b',
            price: 3,
            category: SubscriptionCategory.productivity,
            firstBill: DateTime(2026, 10, 2),
          ),
        ],
        now: _now,
        convert: _identity,
      );
      final oct = h.last;
      expect(oct.total, 8);
      expect(oct.amountFor(_u(SubscriptionCategory.entertainment)), 5);
      expect(oct.amountFor(_u(SubscriptionCategory.productivity)), 3);
      expect(oct.amountFor(_u(SubscriptionCategory.health)), 0);
      // Categories with no bills are absent, not zero.
      expect(h[10].byCategory.keys, [_u(SubscriptionCategory.entertainment)]);
    });

    test('converts each bill from its own currency', () {
      final h = computeSpendHistory(
        subscriptions: [
          _sub(price: 10, currency: 'USD', firstBill: DateTime(2026, 10, 1)),
        ],
        now: _now,
        convert: (amount, from) => from == 'USD' ? amount * 0.8 : amount,
      );
      expect(h.last.total, 8);
    });
  });

  group('SpendHistoryChart', () {
    List<MonthSpend> data() => [
          for (var i = 0; i < 12; i++)
            MonthSpend(
              month: (i + 10) % 12 + 1,
              year: i < 2 ? 2025 : 2026,
              isCurrentMonth: i == 11,
              byCategory: {
                _u(SubscriptionCategory.entertainment): 5,
                if (i.isEven) _u(SubscriptionCategory.productivity): 3,
              },
            ),
        ];

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [spendHistoryProvider.overrideWithValue(data())],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(width: 360, child: SpendHistoryChart()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<double> heights(WidgetTester tester) => [
          for (final g in tester.widget<BarChart>(find.byType(BarChart)).data.barGroups)
            g.barRods.single.toY,
        ];

    testWidgets('All stacks every category, settling at the true totals',
        (tester) async {
      await pump(tester);
      expect(heights(tester), [for (var i = 0; i < 12; i++) i.isEven ? 8 : 5]);
      final rod = tester
          .widget<BarChart>(find.byType(BarChart))
          .data
          .barGroups
          .first
          .barRods
          .single;
      expect(rod.rodStackItems, hasLength(2));
      // Legend names both stacked categories.
      expect(find.text('Entertainment'), findsNWidgets(2)); // chip + legend
    });

    testWidgets('picking a category filters the bars to it', (tester) async {
      await pump(tester);
      final chip = find.widgetWithText(ChoiceChip, 'Productivity');
      await tester.ensureVisible(chip); // the filter row scrolls sideways
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(heights(tester), [for (var i = 0; i < 12; i++) i.isEven ? 3 : 0]);
      // Single series: no legend, only the chip.
      expect(find.text('Entertainment'), findsOneWidget);

      final all = find.widgetWithText(ChoiceChip, 'All');
      await tester.ensureVisible(all);
      await tester.pumpAndSettle();
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(heights(tester).first, 8);
    });

    testWidgets('empty history shows a message, not a blank chart',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [spendHistoryProvider.overrideWithValue([])],
          child: const MaterialApp(home: Scaffold(body: SpendHistoryChart())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BarChart), findsNothing);
      expect(find.text('No bills in the past year yet'), findsOneWidget);
    });
  });
}
