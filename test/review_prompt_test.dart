import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:recurly/models/app_preferences.dart';
import 'package:recurly/utils/review_prompt.dart';

/// Pins when Play's review sheet may be asked for.
///
/// Worth guarding tightly: `requestReview` is quota-limited by Play and
/// silently no-ops once spent, so a mistimed attempt is gone with no error
/// and no retry — a bug here is invisible in production. The rules live in
/// the pure [shouldRequestReview] so they can be pinned without a platform
/// channel; the real sheet only ever appears on a device.
class _FakeInAppReview implements InAppReview {
  _FakeInAppReview({this.available = true});

  final bool available;
  int requestCalls = 0;
  int availabilityChecks = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<void> requestReview() async {
    requestCalls++;
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {}
}

void main() {
  AppPreferences earned() => AppPreferences(
        sessionCount: kReviewMinSessions,
        reviewRequested: false,
      );

  group('shouldRequestReview', () {
    test('asks once the app has been opened again and has real data', () {
      expect(
        shouldRequestReview(earned(), activeSubCount: kReviewMinSubscriptions),
        isTrue,
      );
    });

    test('never on a first run, however much is tracked', () {
      expect(
        shouldRequestReview(
          AppPreferences(sessionCount: 1),
          activeSubCount: 50,
        ),
        isFalse,
      );
    });

    test('not until enough subscriptions to have shown its worth', () {
      expect(
        shouldRequestReview(
          earned(),
          activeSubCount: kReviewMinSubscriptions - 1,
        ),
        isFalse,
      );
    });

    test('never twice — Play only gives us the one attempt', () {
      expect(
        shouldRequestReview(
          AppPreferences(
            sessionCount: 99,
            reviewRequested: true,
          ),
          activeSubCount: 99,
        ),
        isFalse,
      );
    });
  });

  group('AppPreferences review fields', () {
    test('a fresh install starts unasked at zero sessions', () {
      expect(AppPreferences().sessionCount, 0);
      expect(AppPreferences().reviewRequested, isFalse);
    });

    test('survive copyWith', () {
      final updated = AppPreferences().copyWith(
        sessionCount: 4,
        reviewRequested: true,
      );
      expect(updated.sessionCount, 4);
      expect(updated.reviewRequested, isTrue);
    });
  });

  group('maybeRequestReview', () {
    test('requests the sheet and marks it asked when due', () async {
      final reviewer = _FakeInAppReview();
      var marked = 0;

      await maybeRequestReview(
        earned(),
        activeSubCount: kReviewMinSubscriptions,
        markRequested: () async => marked++,
        reviewer: reviewer,
      );

      expect(reviewer.requestCalls, 1);
      expect(marked, 1);
    });

    test('stays silent — and spends nothing — when not due', () async {
      final reviewer = _FakeInAppReview();
      var marked = 0;

      await maybeRequestReview(
        AppPreferences(sessionCount: 1),
        activeSubCount: 99,
        markRequested: () async => marked++,
        reviewer: reviewer,
      );

      expect(reviewer.requestCalls, 0);
      expect(marked, 0);
      // Not even an availability check: the decision is made before we
      // reach for the platform at all.
      expect(reviewer.availabilityChecks, 0);
    });

    test('does not mark asked when the platform offers no sheet', () async {
      // Sideloaded builds and emulators have no Play review flow. Marking
      // there would burn the one attempt on a user who never saw anything.
      final reviewer = _FakeInAppReview(available: false);
      var marked = 0;

      await maybeRequestReview(
        earned(),
        activeSubCount: kReviewMinSubscriptions,
        markRequested: () async => marked++,
        reviewer: reviewer,
      );

      expect(reviewer.availabilityChecks, 1);
      expect(reviewer.requestCalls, 0);
      expect(marked, 0);
    });
  });
}
