import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/budget.dart';
import 'package:recurly/services/budget_service.dart';
import 'package:recurly/utils/changelog.dart';

void main() {
  // P3-1: on a 411dp-wide phone the default sheet (max 9/16 of the screen)
  // clipped "Got it" under the gesture bar once the notes got long.
  testWidgets("What's new: 'Got it' is reachable on a phone", (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final release = kChangelog.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showChangelogSheet(context, release),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final gotIt = find.text('Got it');
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getRect(gotIt).bottom, lessThan(screen.height - 24));
    await tester.tap(gotIt);
    await tester.pumpAndSettle();
    expect(gotIt, findsNothing);
  });

  // P3-2: the alert logic existed but nothing showed it; Home now does.
  group('budget alert timing', () {
    final service = BudgetService();
    BudgetSettings settings({DateTime? last, bool enabled = true}) =>
        BudgetSettings(
          overallMonthlyBudget: 2,
          budgetAlertsEnabled: enabled,
          lastBudgetAlertShown: last,
        );

    test('shows at the threshold, not when safe or switched off', () {
      expect(service.shouldShowAlert(settings(), BudgetStatus.warning), isTrue);
      expect(service.shouldShowAlert(settings(), BudgetStatus.exceeded), isTrue);
      expect(service.shouldShowAlert(settings(), BudgetStatus.safe), isFalse);
      expect(
        service.shouldShowAlert(settings(enabled: false), BudgetStatus.warning),
        isFalse,
      );
    });

    test('dismissed: hidden for a day, back after', () {
      final dismissed = DateTime(2026, 11, 2, 9);
      withClock(Clock.fixed(DateTime(2026, 11, 2, 20)), () {
        expect(
          service.shouldShowAlert(
              settings(last: dismissed), BudgetStatus.warning,),
          isFalse,
        );
      });
      withClock(Clock.fixed(DateTime(2026, 11, 3, 10)), () {
        expect(
          service.shouldShowAlert(
              settings(last: dismissed), BudgetStatus.warning,),
          isTrue,
        );
      });
    });
  });
}
