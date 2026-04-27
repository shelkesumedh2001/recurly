import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../models/sync_status.dart';
import '../services/database_service.dart';
import '../services/home_widget_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import 'auth_providers.dart';
import 'preferences_providers.dart';
import 'sync_providers.dart';

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
    // Subscribe to remote-data-change ticker so Firestore changes refresh UI.
    // Using a listener on a ValueNotifier<int> (instead of assigning a single
    // callback field) lets multiple notifier instances coexist — e.g. across
    // hot reload — without silently overwriting each other.
    SyncService().remoteDataChangeTicker.addListener(_onRemoteTick);
  }

  final DatabaseService _databaseService;
  final NotificationService _notificationService;
  final Ref _ref;

  void _onRemoteTick() {
    loadSubscriptions();
  }

  @override
  void dispose() {
    SyncService().remoteDataChangeTicker.removeListener(_onRemoteTick);
    super.dispose();
  }

  /// Load all active subscriptions
  Future<void> loadSubscriptions() async {
    state = const AsyncValue.loading();
    try {
      final subscriptions = _databaseService.getActiveSubscriptions();
      state = AsyncValue.data(subscriptions);

      // Update home screen widget
      await HomeWidgetService().updateWidgetData();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Push to sync if enabled (fire-and-forget to avoid blocking UI offline)
  void _syncPush(Subscription subscription) {
    final isSyncEnabled = _ref.read(isSyncEnabledProvider);
    if (!isSyncEnabled) return;
    final user = _ref.read(currentFirebaseUserProvider);
    if (user == null) return;
    SyncService().pushSubscription(user.uid, subscription);
  }

  /// Delete from sync if enabled (fire-and-forget)
  void _syncDelete(String id) {
    final isSyncEnabled = _ref.read(isSyncEnabledProvider);
    if (!isSyncEnabled) return;
    final user = _ref.read(currentFirebaseUserProvider);
    if (user == null) return;
    SyncService().deleteRemoteSubscription(user.uid, id);
  }

  /// Add a new subscription
  Future<void> addSubscription(Subscription subscription) async {
    try {
      subscription.updatedAt = DateTime.now();
      await _databaseService.addSubscription(subscription);
      await loadSubscriptions();
      _syncPush(subscription);

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
      subscription.updatedAt = DateTime.now();
      await _databaseService.updateSubscription(subscription);
      await loadSubscriptions();
      _syncPush(subscription);

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
      _syncDelete(id);
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
  return count >= AppConstants.freeSubscriptionLimit;
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
        return subscriptions.where((sub) => sub.category.categoryName == categoryName).toList();
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

/// Provider for spend view mode (my share vs household total)
final spendViewModeProvider = StateProvider<SpendViewMode>((ref) {
  return SpendViewMode.myShare;
});

/// Provider for partner subscriptions (from household sync) — reactive via stream
final partnerSubscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final controller = StreamController<List<Subscription>>();
  controller.add(syncService.partnerSubscriptions.value);
  void listener() {
    if (!controller.isClosed) {
      controller.add(syncService.partnerSubscriptions.value);
    }
  }
  syncService.partnerSubscriptions.addListener(listener);
  ref.onDispose(() {
    syncService.partnerSubscriptions.removeListener(listener);
    controller.close();
  });
  return controller.stream;
});

/// Provider for household subscriptions (own + partner)
final householdSubscriptionsProvider = Provider<List<Subscription>>((ref) {
  final ownSubs = ref.watch(subscriptionProvider).value ?? [];
  final partnerSubs = ref.watch(partnerSubscriptionsProvider).value ?? [];
  return [...ownSubs, ...partnerSubs];
});

/// Provider for "my share" spend — factors in split percentages
final myShareSpendProvider = Provider<double>((ref) {
  final subscriptionsAsync = ref.watch(subscriptionProvider);

  return subscriptionsAsync.when(
    data: (subscriptions) {
      double total = 0;
      for (final sub in subscriptions) {
        if (sub.splitWith != null && sub.splitWith!.isNotEmpty) {
          // Find accepted splits
          double myMultiplier = 1.0;
          for (final split in sub.splitWith!) {
            if (split['accepted'] == true) {
              final partnerShare = (split['sharePercent'] as num).toDouble();
              myMultiplier -= partnerShare / 100;
            }
          }
          total += sub.monthlyEquivalent * myMultiplier;
        } else {
          total += sub.monthlyEquivalent;
        }
      }
      return total;
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider for household total spend (own + partner, no double-count splits)
final householdTotalSpendProvider = Provider<double>((ref) {
  final ownSubs = ref.watch(subscriptionProvider).value ?? [];
  final partnerSubs = ref.watch(partnerSubscriptionsProvider).value ?? [];

  double total = 0;
  // Own subs: full price (since partner's share is included in household total)
  for (final sub in ownSubs) {
    total += sub.monthlyEquivalent;
  }
  // Partner subs: only add those that aren't split references from our own
  final ownIds = ownSubs.map((s) => s.id).toSet();
  for (final sub in partnerSubs) {
    if (!ownIds.contains(sub.id)) {
      total += sub.monthlyEquivalent;
    }
  }
  return total;
});
