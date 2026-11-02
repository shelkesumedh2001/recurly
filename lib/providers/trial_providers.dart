import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import 'auth_providers.dart';
import 'subscription_providers.dart';

/// Provider for all free trial subscriptions
final freeTrialSubscriptionsProvider = Provider<List<Subscription>>((ref) {
  final subscriptions = ref.watch(subscriptionProvider).value ?? [];
  return subscriptions
      .where((sub) => sub.isFreeTrial && !sub.isArchived && sub.deletedAt == null)
      .toList();
});

/// Provider for trials expiring soon (within 7 days)
final expiringTrialsProvider = Provider<List<Subscription>>((ref) {
  final trials = ref.watch(freeTrialSubscriptionsProvider);
  return trials
      .where((sub) => sub.daysUntilTrialEnds >= 0 && sub.daysUntilTrialEnds <= 7)
      .toList()
    ..sort((a, b) => a.daysUntilTrialEnds.compareTo(b.daysUntilTrialEnds));
});

/// Own trials whose end date has passed and that the user hasn't yet
/// confirmed (kept → converted to a paid sub) or cancelled (archived).
/// They're already counted at the post-trial price ([Subscription.currentPrice]);
/// Home shows a "still subscribed?" banner for each one.
final expiredTrialsProvider = Provider<List<Subscription>>((ref) {
  final trials = ref.watch(freeTrialSubscriptionsProvider);
  final uid = ref.watch(currentFirebaseUserProvider)?.uid;
  return trials
      .where((sub) => sub.isTrialExpired)
      // A partner's split copy is theirs to confirm, not ours.
      .where((sub) => sub.ownerUid == null || sub.ownerUid == uid)
      .toList();
});

/// Count of active free trials
final freeTrialCountProvider = Provider<int>((ref) {
  return ref.watch(freeTrialSubscriptionsProvider).length;
});

/// Total potential cost when all trials end
final totalTrialCostProvider = Provider<double>((ref) {
  final trials = ref.watch(freeTrialSubscriptionsProvider);
  return trials.fold(
    0,
    (sum, sub) => sum + sub.monthlyEquivalentOf(sub.chargePerRenewal),
  );
});

/// Provider for trial that will end soonest
final soonestExpiringTrialProvider = Provider<Subscription?>((ref) {
  final expiring = ref.watch(expiringTrialsProvider);
  if (expiring.isEmpty) return null;
  return expiring.first;
});
