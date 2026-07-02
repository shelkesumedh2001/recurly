import 'package:clock/clock.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/budget.dart';
import 'package:recurly/models/credit_card.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/providers/credit_card_providers.dart';
import 'package:recurly/providers/subscription_providers.dart';
import 'package:recurly/services/credit_card_service.dart';
import 'package:recurly/services/database_service.dart';
import 'package:recurly/services/notification_service.dart';
import 'package:recurly/theme/app_theme.dart';
import 'package:recurly/theme/theme_presets.dart';
import 'package:recurly/widgets/analytics/renewal_calendar.dart';
import 'package:recurly/widgets/budget/budget_progress_bar.dart';
import 'package:recurly/widgets/subscription_card.dart';
import 'package:recurly/widgets/theme/theme_preview_card.dart';
import 'package:recurly/widgets/trial/trial_badge.dart';

/// Golden tests for the core visual widgets.
///
/// All date-derived UI (renewal countdowns, "Next: <date>" labels, trial
/// badges) is pinned via `withClock(Clock.fixed(_now))` — the Subscription
/// model reads `clock.now()` — so these images never rot as real time passes.
///
/// Regenerate after an intentional UI change with:
///   flutter test test/goldens_test.dart --update-goldens

/// Frozen "today" for every scenario in this file.
final DateTime _now = DateTime(2026, 7, 15, 12);

Subscription _sub({
  required String id,
  required String name,
  double price = 9.99,
  String currency = 'USD',
  BillingCycle billingCycle = BillingCycle.monthly,
  SubscriptionCategory category = SubscriptionCategory.entertainment,
  DateTime? firstBillDate,
  bool isFreeTrial = false,
  DateTime? trialEndDate,
}) {
  return Subscription(
    id: id,
    name: name,
    price: price,
    currency: currency,
    billingCycle: billingCycle,
    category: category,
    // firstBillDate anchors nextBillDate: (_now - 1 month + N days) renews
    // in N days under the fixed clock.
    firstBillDate: firstBillDate ?? DateTime(2026, 6, 15),
    createdAt: DateTime(2026, 1, 1),
    isFreeTrial: isFreeTrial,
    trialEndDate: trialEndDate,
  );
}

/// SubscriptionNotifier whose state is pinned to a fixed sub list, so
/// provider-driven widgets (e.g. RenewalCalendar) can be golden-tested
/// without Hive/Firestore backing data.
class _StubSubscriptionNotifier extends SubscriptionNotifier {
  _StubSubscriptionNotifier(super.db, super.ns, super.ref, List<Subscription> subs) {
    state = AsyncValue.data(subs);
  }
}

/// Same idea for tracked credit cards.
class _StubCreditCardNotifier extends CreditCardNotifier {
  _StubCreditCardNotifier(super.service, super.ref, List<CreditCardInfo> cards) {
    state = cards;
  }
}

Widget _harness(Widget child, {bool dark = false, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.getDarkTheme() : AppTheme.getLightTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: child,
        ),
      ),
    ),
  );
}

/// Pumps [widget] under the fixed clock and compares against [goldenName].
Future<void> _expectGolden(
  WidgetTester tester,
  Widget widget,
  String goldenName,
) async {
  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(widget);
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  });
}

void main() {
  setUpAll(() async {
    // SubscriptionCard reads subscriptionProvider.notifier during build,
    // whose constructor touches SyncService → FirebaseFirestore.instance.
    // The mocked core app satisfies that chain without real Firebase.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    // 400x1000 logical pixels at dpr 1 — tall phone-ish canvas.
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(400, 1000)
      ..devicePixelRatio = 1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  group('SubscriptionCard goldens', () {
    Widget cards() {
      return Column(
        children: [
          // Renews in 30 days → normal urgency color.
          SubscriptionCard(
            subscription: _sub(
              id: 'g-normal',
              name: 'Netflix',
              price: 15.49,
              firstBillDate: DateTime(2026, 7, 14),
            ),
          ),
          // Renews in 10 days → warning urgency color.
          SubscriptionCard(
            subscription: _sub(
              id: 'g-warning',
              name: 'Spotify',
              price: 11.99,
              category: SubscriptionCategory.productivity,
              firstBillDate: DateTime(2026, 6, 25),
            ),
          ),
          // Renews in 2 days → urgent color.
          SubscriptionCard(
            subscription: _sub(
              id: 'g-urgent',
              name: 'iCloud+',
              price: 2.99,
              category: SubscriptionCategory.utilities,
              firstBillDate: DateTime(2026, 6, 17),
            ),
          ),
          // Active free trial ending in 5 days.
          SubscriptionCard(
            subscription: _sub(
              id: 'g-trial',
              name: 'Disney+',
              price: 7.99,
              isFreeTrial: true,
              trialEndDate: DateTime(2026, 7, 20),
              firstBillDate: DateTime(2026, 7, 1),
            ),
          ),
          // Partner sub → read-only variant with no swipe affordances.
          SubscriptionCard(
            isPartnerSub: true,
            subscription: _sub(
              id: 'g-partner',
              name: 'YouTube Premium',
              price: 13.99,
              currency: 'EUR',
              firstBillDate: DateTime(2026, 7, 5),
            ),
          ),
        ],
      );
    }

    testWidgets('light theme states', (tester) async {
      await _expectGolden(
        tester,
        _harness(cards()),
        'subscription_card_states_light',
      );
    });

    testWidgets('dark theme states', (tester) async {
      await _expectGolden(
        tester,
        _harness(cards(), dark: true),
        'subscription_card_states_dark',
      );
    });
  });

  group('RenewalCalendar goldens', () {
    testWidgets('heatmap + card due marker + selected card-due tile',
        (tester) async {
      // Fixed July 2026: Netflix renews Jul 20 (heatmap cell), a card with
      // dueDay 25 puts a due marker on Jul 25.
      final subs = [
        _sub(
          id: 'g-cal-netflix',
          name: 'Netflix',
          price: 15.49,
          firstBillDate: DateTime(2026, 6, 20),
        ),
      ];

      final cards = [
        CreditCardInfo(
          id: 'g-card',
          name: 'HDFC Regalia',
          cutoffDay: 15,
          dueDay: 25,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      final widget = _harness(
        const SingleChildScrollView(child: RenewalCalendar()),
        overrides: [
          subscriptionProvider.overrideWith(
            (ref) => _StubSubscriptionNotifier(
              DatabaseService(),
              NotificationService(),
              ref,
              subs,
            ),
          ),
          creditCardsProvider.overrideWith(
            (ref) => _StubCreditCardNotifier(CreditCardService(), ref, cards),
          ),
        ],
      );

      await withClock(Clock.fixed(_now), () async {
        await tester.pumpWidget(widget);
        await tester.pump();
        // Select the card's due day so the "payment due" tile renders.
        await tester.tap(find.text('25'));
        await tester.pump();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/renewal_calendar_light.png'),
        );
      });
    });
  });

  group('Leaf widget goldens', () {
    testWidgets('budget bars, trial badges, theme preview', (tester) async {
      final trialSub = _sub(
        id: 'g-badge-active',
        name: 'Trial',
        isFreeTrial: true,
        trialEndDate: DateTime(2026, 7, 20),
      );
      final trialUrgent = _sub(
        id: 'g-badge-urgent',
        name: 'Trial',
        isFreeTrial: true,
        trialEndDate: DateTime(2026, 7, 17),
      );
      final trialExpired = _sub(
        id: 'g-badge-expired',
        name: 'Trial',
        isFreeTrial: true,
        trialEndDate: DateTime(2026, 7, 10),
      );

      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BudgetProgressBar(usage: 0.45, status: BudgetStatus.safe),
          const SizedBox(height: 12),
          const BudgetProgressBar(usage: 0.85, status: BudgetStatus.warning),
          const SizedBox(height: 12),
          const BudgetProgressBar(usage: 1.25, status: BudgetStatus.exceeded),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TrialBadge(subscription: trialSub),
              TrialBadge(subscription: trialUrgent),
              TrialBadge(subscription: trialExpired),
              TrialBadge(subscription: trialSub, compact: true),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            width: 120,
            child: ThemePreviewCard(
              preset: ThemePresets.ocean,
              isSelected: true,
              onTap: () {},
            ),
          ),
        ],
      );

      await _expectGolden(tester, _harness(content), 'leaf_widgets_light');
    });
  });
}
