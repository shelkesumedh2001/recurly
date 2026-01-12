import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'preferences_providers.dart';

/// Provider for the database service singleton
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// State notifier for managing subscriptions
class SubscriptionNotifier extends StateNotifier<AsyncValue<List<Subscription>>> {

  SubscriptionNotifier(
    this._databaseService,
    this._notificationService,
    this._ref,
  ) : super(const AsyncValue.loading()) {
    loadSubscriptions();
  }

  final DatabaseService _databaseService;
  final NotificationService _notificationService;
  final Ref _ref;

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

      // Schedule notifications for new subscription
      final preferences = _ref.read(preferencesProvider);
      await _notificationService.scheduleSubscriptionNotifications(
        subscription,
        preferences,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing subscription
  Future<void> updateSubscription(Subscription subscription) async {
    try {
      await _databaseService.updateSubscription(subscription);
      await loadSubscriptions();

      // Reschedule notifications for updated subscription
      final preferences = _ref.read(preferencesProvider);
      await _notificationService.scheduleSubscriptionNotifications(
        subscription,
        preferences,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a subscription
  Future<void> deleteSubscription(String id) async {
    try {
      // Cancel notifications before deleting
      await _notificationService.cancelSubscriptionNotifications(id);
      await _databaseService.deleteSubscription(id);
      await loadSubscriptions();
    } catch (e) {
      rethrow;
    }
  }

  /// Archive a subscription
  Future<void> archiveSubscription(String id) async {
    try {
      // Cancel notifications before archiving
      await _notificationService.cancelSubscriptionNotifications(id);
      await _databaseService.archiveSubscription(id);
      await loadSubscriptions();
    } catch (e) {
      rethrow;
    }
  }

  /// Restore subscription from recently deleted
  Future<void> restoreFromRecentlyDeleted(String id) async {
    try {
      await _databaseService.restoreFromRecentlyDeleted(id);
      await loadSubscriptions();

      // Reschedule notifications after restoring
      final subscription = _databaseService.getSubscriptionById(id);
      if (subscription != null) {
        final preferences = _ref.read(preferencesProvider);
        await _notificationService.scheduleSubscriptionNotifications(
          subscription,
          preferences,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sort subscriptions by different criteria
  void sortByDate() {
    final current = state.value;
    if (current != null) {
      final sorted = List<Subscription>.from(current)
        ..sort((a, b) => a.nextBillDate.compareTo(b.nextBillDate));
      state = AsyncValue.data(sorted);
    }
  }

  void sortByPrice() {
    final current = state.value;
    if (current != null) {
      final sorted = List<Subscription>.from(current)
        ..sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));
      state = AsyncValue.data(sorted);
    }
  }

  void sortByName() {
    final current = state.value;
    if (current != null) {
      final sorted = List<Subscription>.from(current)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      state = AsyncValue.data(sorted);
    }
  }
}

/// Provider for subscription state
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<List<Subscription>>>(
  (ref) {
    final databaseService = ref.watch(databaseServiceProvider);
    final notificationService = ref.watch(notificationServiceProvider);
    return SubscriptionNotifier(databaseService, notificationService, ref);
  },
);

/// Provider for total monthly spend
final totalMonthlySpendProvider = Provider<double>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      return subscriptions.fold<double>(
        0,
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
    error: AsyncValue.error,
  );
});

/// Provider for recently deleted subscriptions
final recentlyDeletedProvider = StateProvider<List<Subscription>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getRecentlyDeletedSubscriptions();
});
