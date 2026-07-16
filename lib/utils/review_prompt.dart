import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../models/app_preferences.dart';

/// Play's in-app review sheet, asked once, at a moment that earns it.
///
/// Why it's worth the code: the listing has no star rating at all, so every
/// visitor sees a blank where social proof goes, and Play's ranking leans on
/// rating count and velocity. This is the cheapest thing that moves either.
///
/// Why the gating is conservative: `requestReview` is quota-limited by Play
/// and silently does nothing once spent, so a badly-timed attempt is simply
/// wasted — there's no retry and no feedback. Ask on a first run and you
/// rate a first impression rather than the app.
const int kReviewMinSessions = 2;
const int kReviewMinSubscriptions = 3;

/// Whether the review prompt is due. Pure: the caller supplies the state,
/// so the rules can be pinned without a platform channel or a widget tree.
@visibleForTesting
bool shouldRequestReview(
  AppPreferences prefs, {
  required int activeSubCount,
}) {
  // Asked once; Play won't show it again anyway.
  if (prefs.reviewRequested) return false;
  // Not on someone's first run.
  if (prefs.sessionCount < kReviewMinSessions) return false;
  // Enough tracked for the app to have shown its worth — and for the
  // monthly total to be a real number rather than a single row.
  if (activeSubCount < kReviewMinSubscriptions) return false;
  return true;
}

/// Requests the review sheet if [shouldRequestReview] agrees and the
/// platform offers one. Marks it asked either way: a declined or
/// quota-swallowed attempt is still spent, and retrying on every launch
/// would only burn the quota.
///
/// Fire-and-forget by design — Play gives no callback for what the user
/// did, and there is nothing sensible to do differently either way.
Future<void> maybeRequestReview(
  AppPreferences prefs, {
  required int activeSubCount,
  required Future<void> Function() markRequested,
  InAppReview? reviewer,
}) async {
  if (!shouldRequestReview(prefs, activeSubCount: activeSubCount)) return;

  final review = reviewer ?? InAppReview.instance;
  if (!await review.isAvailable()) return;

  await markRequested();
  await review.requestReview();
}
