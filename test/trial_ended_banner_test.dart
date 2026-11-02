import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/main.dart' show rootNavigatorKey;
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/providers/subscription_providers.dart';
import 'package:recurly/providers/trial_providers.dart';
import 'package:recurly/widgets/trial/trial_ended_banner.dart';

/// Records calls; the real notifier needs Hive + notifications.
class _FakeNotifier extends StateNotifier<AsyncValue<List<Subscription>>>
    implements SubscriptionNotifier {
  _FakeNotifier(this.expired) : super(const AsyncValue.data([]));

  final StateController<List<Subscription>> expired;
  final calls = <String>[];
  Subscription? updated;

  @override
  Future<void> archiveSubscription(String id) async {
    calls.add('archive $id');
    expired.state = []; // archived → no longer an unconfirmed trial
  }

  @override
  Future<void> unarchiveSubscription(String id) async =>
      calls.add('unarchive $id');

  @override
  Future<void> updateSubscription(Subscription subscription) async {
    calls.add('update ${subscription.id}');
    updated = subscription;
    expired.state = [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final duolingo = Subscription(
    id: 'duo',
    name: 'Duolingo',
    price: 0,
    billingCycle: BillingCycle.monthly,
    firstBillDate: DateTime(2026, 11, 16),
    category: SubscriptionCategory.other,
    createdAt: DateTime(2026, 11, 2),
    isFreeTrial: true,
    trialEndDate: DateTime(2026, 11, 16),
    priceAfterTrial: 9.99,
  );

  late _FakeNotifier notifier;

  Future<void> pump(WidgetTester tester) async {
    final expired = StateProvider<List<Subscription>>((_) => [duolingo]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expiredTrialsProvider.overrideWith((ref) => ref.watch(expired)),
          subscriptionProvider.overrideWith((ref) {
            notifier = _FakeNotifier(ref.read(expired.notifier));
            return notifier;
          }),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Scaffold(body: TrialEndedBanners()),
        ),
      ),
    );
  }

  testWidgets('shows the post-trial price and asks', (tester) async {
    await pump(tester);
    expect(find.text('Duolingo trial ended Nov 16'), findsOneWidget);
    expect(find.textContaining(r'$9.99 a month'), findsOneWidget);
  });

  testWidgets('"I cancelled" archives, and Undo still works after the '
      'banner is gone', (tester) async {
    await pump(tester);
    await tester.tap(find.text('I cancelled'));
    await tester.pump();
    expect(notifier.calls, ['archive duo']);
    expect(find.text('I cancelled'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400)); // toast in
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(notifier.calls, ['archive duo', 'unarchive duo']);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('"Yes, keep it" saves a normal paid sub', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Yes, keep it'));
    await tester.pump();
    final saved = notifier.updated!;
    expect(saved.isFreeTrial, isFalse);
    expect(saved.price, 9.99);
    expect(saved.trialEndDate, isNull);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
