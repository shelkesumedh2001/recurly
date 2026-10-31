import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  bool isFreeTrial = false,
  DateTime? trialEndDate,
  double? priceAfterTrial,
  int? customDays,
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
      isFreeTrial: isFreeTrial,
      trialEndDate: trialEndDate,
      priceAfterTrial: priceAfterTrial,
      customDays: customDays,
    );

double _identity(double amount, String from) => amount;

List<MonthSpend> _timeline(List<Subscription> subs) => computeSpendTimeline(
      subscriptions: subs,
      now: _now,
      convert: _identity,
    );

List<double> _totals(Iterable<MonthSpend> h) => [for (final m in h) m.total];

/// The 12 billed months (past + current).
List<MonthSpend> _billed(List<MonthSpend> t) =>
    t.where((m) => !m.isEstimate).toList();

/// The 6 estimated months.
List<MonthSpend> _future(List<MonthSpend> t) =>
    t.where((m) => m.isEstimate).toList();

void main() {
  group('computeSpendTimeline — shape', () {
    test('11 past, this month, then 6 estimated, oldest first', () {
      final t = _timeline(const []);
      expect(t, hasLength(18));
      expect((t.first.year, t.first.month), (2025, 11));
      expect((t[11].year, t[11].month), (2026, 10));
      expect((t.last.year, t.last.month), (2027, 4));
      expect(t.where((m) => m.period == SpendPeriod.past), hasLength(11));
      expect(t[11].period, SpendPeriod.current);
      expect(t.skip(12).every((m) => m.isEstimate), isTrue);
    });
  });

  group('computeSpendTimeline — billed (facts)', () {
    test('monthly sub bills every month from its first bill, not before', () {
      final t = _timeline([_sub(firstBill: DateTime(2026, 7, 3))]);
      expect(_totals(_billed(t)), [0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 5, 5]);
    });

    test('this month includes a bill still due later this month', () {
      final t = _timeline([_sub(firstBill: DateTime(2026, 9, 28))]);
      expect(t[11].total, 5); // Oct 28 bill, today is Oct 20
    });

    test('yearly sub spikes only in its renewal month', () {
      final t = _timeline([
        _sub(price: 60, cycle: BillingCycle.yearly, firstBill: DateTime(2024, 3, 10)),
      ]);
      expect(_totals(_billed(t)), [0, 0, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0]);
      expect(_totals(_future(t)), [0, 0, 0, 0, 60, 0]); // Nov–Apr: Mar 2027
    });

    test('weekly sub bills 4 or 5 times depending on the month', () {
      // Thursdays from 1 Jan 2026.
      final t = _timeline([
        _sub(price: 1, cycle: BillingCycle.weekly, firstBill: DateTime(2026, 1, 1)),
      ]);
      expect(t[2].total, 5); // Jan 2026: 5 Thursdays
      expect(t[3].total, 4); // Feb 2026: 4
    });

    test('bills are priced at what they cost on the day', () {
      final t = _timeline([
        _sub(
          price: 7,
          firstBill: DateTime(2026, 5, 15),
          priceHistory: [
            {'price': 5.0, 'currency': 'GBP', 'date': '2026-07-01T09:00:00.000'},
            {'price': 6.0, 'currency': 'GBP', 'date': '2026-09-01T09:00:00.000'},
          ],
        ),
      ]);
      // May/Jun at 5, Jul/Aug at 6, Sep/Oct at 7 — and the future at 7.
      expect(_totals(_billed(t)).sublist(6), [5, 5, 6, 6, 7, 7]);
      expect(_totals(_future(t)), List.filled(6, 7));
    });

    test('splits by category; categories with no bills are absent', () {
      final t = _timeline([
        _sub(id: 'a', price: 5, firstBill: DateTime(2026, 9, 1)),
        _sub(
          id: 'b',
          price: 3,
          category: SubscriptionCategory.productivity,
          firstBill: DateTime(2026, 10, 2),
        ),
      ]);
      final oct = t[11];
      expect(oct.total, 8);
      expect(oct.amountFor(SubscriptionCategory.entertainment), 5);
      expect(oct.amountFor(SubscriptionCategory.productivity), 3);
      expect(oct.amountFor(SubscriptionCategory.health), 0);
      expect(t[10].byCategory.keys, [SubscriptionCategory.entertainment]);
    });

    test('converts each bill from its own currency', () {
      final t = computeSpendTimeline(
        subscriptions: [
          _sub(price: 10, currency: 'USD', firstBill: DateTime(2026, 10, 1)),
        ],
        now: _now,
        convert: (amount, from) => from == 'USD' ? amount * 0.8 : amount,
      );
      expect(t[11].total, 8);
    });
  });

  group('computeSpendTimeline — estimate (the old projection bugs)', () {
    test('a free trial bills from trial end at the post-trial price', () {
      final t = _timeline([
        _sub(
          price: 0,
          firstBill: DateTime(2026, 10, 1),
          isFreeTrial: true,
          trialEndDate: DateTime(2027, 1, 5),
          priceAfterTrial: 12,
        ),
      ]);
      // Nov, Dec free; Jan onwards 12.
      expect(_totals(_future(t)), [0, 0, 12, 12, 12, 12]);
    });

    test('a sub starting later bills only from its start', () {
      final t = _timeline([_sub(firstBill: DateTime(2027, 2, 10))]);
      expect(_totals(_future(t)), [0, 0, 0, 5, 5, 5]);
    });

    test('a custom 90-day cycle spikes instead of being averaged', () {
      final t = _timeline([
        _sub(
          price: 30,
          cycle: BillingCycle.custom,
          customDays: 90,
          firstBill: DateTime(2026, 10, 10),
        ),
      ]);
      // Oct 10 → Jan 8 → Apr 8.
      expect(_totals(_future(t)), [0, 0, 30, 0, 0, 30]);
    });
  });

  group('findSpikes', () {
    test('names the yearly renewal behind a bigger coming month', () {
      final t = _timeline([
        _sub(id: 'Netflix', price: 10, firstBill: DateTime(2026, 1, 4)),
        _sub(
          id: 'Prime',
          price: 95,
          cycle: BillingCycle.yearly,
          firstBill: DateTime(2026, 1, 15),
        ),
      ]);
      final spikes = findSpikes(t);
      expect(spikes, hasLength(1));
      expect((spikes.single.month.year, spikes.single.month.month), (2027, 1));
      expect(spikes.single.amount, 105);
      expect(spikes.single.usual, 10);
      expect(spikes.single.causes.map((b) => b.name), ['Prime']);
    });

    test('a flat future has no spikes', () {
      expect(findSpikes(_timeline([_sub(firstBill: DateTime(2026, 1, 4))])), isEmpty);
    });

    test('a 5-week month of a weekly sub alone is not a spike', () {
      final t = _timeline([
        _sub(price: 10, cycle: BillingCycle.weekly, firstBill: DateTime(2026, 1, 1)),
      ]);
      expect(findSpikes(t), isEmpty);
    });

    test('respects the category filter', () {
      final t = _timeline([
        _sub(
          id: 'Prime',
          price: 95,
          cycle: BillingCycle.yearly,
          firstBill: DateTime(2026, 1, 15),
        ),
        _sub(
          id: 'Notion',
          price: 8,
          category: SubscriptionCategory.productivity,
          firstBill: DateTime(2026, 1, 2),
        ),
      ]);
      expect(findSpikes(t, filter: SubscriptionCategory.productivity), isEmpty);
      expect(findSpikes(t, filter: SubscriptionCategory.entertainment), hasLength(1));
    });
  });

  group('SpendHistoryChart', () {
    // 12 billed months then 6 estimated; entertainment 5 every month,
    // productivity 3 on even months.
    List<MonthSpend> data() => [
          for (var i = 0; i < 18; i++)
            MonthSpend(
              month: (i + 10) % 12 + 1,
              year: 2025 + (i + 10) ~/ 12,
              period: i < 11
                  ? SpendPeriod.past
                  : i == 11
                      ? SpendPeriod.current
                      : SpendPeriod.future,
              byCategory: {
                SubscriptionCategory.entertainment: 5,
                if (i.isEven) SubscriptionCategory.productivity: 3,
              },
            ),
        ];

    Future<void> pump(WidgetTester tester, [List<MonthSpend>? d]) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [spendTimelineProvider.overrideWithValue(d ?? data())],
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

    List<BarChartGroupData> groups(WidgetTester tester) =>
        tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

    List<double?> heights(WidgetTester tester) => [
          for (final g in groups(tester))
            g.barRods.isEmpty ? null : g.barRods.single.toY,
        ];

    Future<void> tapChip(WidgetTester tester, String label) async {
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(chip); // the filter row scrolls sideways
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('bars settle at true totals, with a gap before the estimate',
        (tester) async {
      await pump(tester);
      expect(heights(tester), [
        for (var i = 0; i < 12; i++) i.isEven ? 8 : 5,
        null, // the "today" gap
        for (var i = 12; i < 18; i++) i.isEven ? 8 : 5,
      ]);
    });

    testWidgets('estimated bars look different from billed ones',
        (tester) async {
      await pump(tester);
      final g = groups(tester);
      final billed = g[11].barRods.single;
      final estimate = g[13].barRods.single;
      expect(billed.borderDashArray, isNull);
      expect(estimate.borderDashArray, isNotNull);
      expect(estimate.borderSide.width, greaterThan(0));
      // Same category, fainter fill.
      expect(
        estimate.rodStackItems.first.color.a,
        lessThan(billed.rodStackItems.first.color.a),
      );
      expect(find.text('Billed'), findsOneWidget);
      expect(find.text('Estimate'), findsOneWidget);
    });

    testWidgets('headline totals only billed months; estimate stated apart',
        (tester) async {
      await pump(tester);
      // 6×8 + 6×5 = 78 billed.
      expect(find.textContaining('78.00'), findsOneWidget);
      expect(find.textContaining('Next 6 months: about'), findsOneWidget);
    });

    testWidgets('picking a category filters both halves', (tester) async {
      await pump(tester);
      await tapChip(tester, 'Productivity');
      expect(heights(tester), [
        for (var i = 0; i < 12; i++) i.isEven ? 3 : 0,
        null,
        for (var i = 12; i < 18; i++) i.isEven ? 3 : 0,
      ]);
      // Single series: no legend, only the chip.
      expect(find.text('Entertainment'), findsOneWidget);

      await tapChip(tester, 'All');
      expect(heights(tester).first, 8);
    });

    testWidgets('empty timeline shows a message, not a blank chart',
        (tester) async {
      await pump(tester, []);
      expect(find.byType(BarChart), findsNothing);
      expect(find.text('No bills to show yet'), findsOneWidget);
    });
  });
}
