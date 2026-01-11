import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../services/database_service.dart';

/// Provider for the database service singleton
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// State notifier for managing subscriptions
class SubscriptionNotifier extends StateNotifier<AsyncValue<List<Subscription>>> {
  final DatabaseService _databaseService;

  SubscriptionNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    loadSubscriptions();
  }

  /// Load all active subscriptions
  Future<void> loadSubscriptions() async {
    state = const AsyncValue.loading();
    try {
      final subscriptions = _databaseService.getActiveSubscriptions();
      state = AsyncValue.data(subscriptions);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Add a new subscription
  Future<void> addSubscription(Subscription subscription) async {
    try {
      await _databaseService.addSubscription(subscription);
      await loadSubscriptions();
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing subscription
  Future<void> updateSubscription(Subscription subscription) async {
    try {
      await _databaseService.updateSubscription(subscription);
      await loadSubscriptions();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a subscription
  Future<void> deleteSubscription(String id) async {
    try {
      await _databaseService.deleteSubscription(id);
      await loadSubscriptions();
    } catch (e) {
      rethrow;
    }
  }

  /// Archive a subscription
  Future<void> archiveSubscription(String id) async {
    try {
      await _databaseService.archiveSubscription(id);
      await loadSubscriptions();
    } catch (e) {
      rethrow;
    }
  }

  /// Sort subscriptions by different criteria
  void sortByDate() {
    final current = state.value;
    if (current != null) {
      final sorted = List<Subscription>.from(current);
      sorted.sort((a, b) => a.nextBillDate.compareTo(b.nextBillDate));
      state = AsyncValue.data(sorted);
    }
  }

  void sortByPrice() {
    final current = state.value;
    if (current != null) {
      final sorted = List<Subscription>.from(current);
      sorted.sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));
      state = AsyncValue.data(sorted);
    }
  }

  void sortByName() {
    final current = state.value;
    if (current != null) {
      final sorted = List<Subscription>.from(current);
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      state = AsyncValue.data(sorted);
    }
  }
}

/// Provider for subscription state
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<List<Subscription>>>(
  (ref) {
    final databaseService = ref.watch(databaseServiceProvider);
    return SubscriptionNotifier(databaseService);
  },
);

/// Provider for total monthly spend
final totalMonthlySpendProvider = Provider<double>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      return subscriptions.fold<double>(
        0.0,
        (sum, sub) => sum + sub.monthlyEquivalent,
      );
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider for active subscription count
final activeSubscriptionCountProvider = Provider<int>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) => subscriptions.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for checking if free limit is reached
final hasReachedFreeLimitProvider = Provider<bool>((ref) {
  final count = ref.watch(activeSubscriptionCountProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  return count >= 5; // Free limit
});

/// Provider for pro status (placeholder - will integrate with RevenueCat)
final isProUserProvider = StateProvider<bool>((ref) => false);

/// Provider for subscriptions expiring soon (within 7 days)
final subscriptionsExpiringSoonProvider = Provider<List<Subscription>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      return subscriptions.where((sub) => sub.daysUntilRenewal <= 7).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for subscriptions by category
final subscriptionsByCategoryProvider = Provider.family<List<Subscription>, String>(
  (ref, categoryName) {
    final subscriptionsAsync = ref.watch(subscriptionProvider);

    return subscriptionsAsync.when(
      data: (subscriptions) {
        return subscriptions.where((sub) => sub.category.name == categoryName).toList();
      },
      loading: () => [],
      error: (_, __) => [],
    );
  },
);

/// Provider for search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for filtered subscriptions based on search query
final filteredSubscriptionsProvider = Provider<AsyncValue<List<Subscription>>>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      if (searchQuery.isEmpty) {
        return AsyncValue.data(subscriptions);
      }

      final filtered = subscriptions.where((sub) {
        return sub.name.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for recently deleted subscriptions
final recentlyDeletedProvider = StateProvider<List<Subscription>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getRecentlyDeletedSubscriptions();
});
