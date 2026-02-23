import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
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

/// Provider for expired trials
final expiredTrialsProvider = Provider<List<Subscription>>((ref) {
  final trials = ref.watch(freeTrialSubscriptionsProvider);
  return trials.where((sub) => sub.isTrialExpired).toList();
});

/// Count of active free trials
final freeTrialCountProvider = Provider<int>((ref) {
  return ref.watch(freeTrialSubscriptionsProvider).length;
});

/// Total potential cost when all trials end
final totalTrialCostProvider = Provider<double>((ref) {
  final trials = ref.watch(freeTrialSubscriptionsProvider);
  return trials.fold(0.0, (sum, sub) {
    final price = sub.priceAfterTrial ?? sub.price;
    return sum + price * sub.billingCycle.getMonthlyMultiplier();
  });
});

/// Provider for trial that will end soonest
final soonestExpiringTrialProvider = Provider<Subscription?>((ref) {
  final expiring = ref.watch(expiringTrialsProvider);
  if (expiring.isEmpty) return null;
  return expiring.first;
});
