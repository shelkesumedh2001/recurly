import 'dart:async';

import 'package:clock/clock.dart';
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

  /// Load all active subscriptions.
  ///
  /// Does NOT reset state to loading on refresh — that would flash a
  /// spinner over the list every time a sub is added/edited/deleted, and
  /// (worse) the resulting body rebuild thrashes any visible snackbar's
  /// animation, leaving "moved to recently deleted — Undo" pills stuck
  /// indefinitely. Initial loading state is set once via the constructor's
  /// `super(const AsyncValue.loading())`.
  Future<void> loadSubscriptions() async {
    try {
      final subscriptions =
          _applySortMode(_databaseService.getActiveSubscriptions());
      state = AsyncValue.data(subscriptions);

      // Update home screen widget
      await HomeWidgetService().updateWidgetData();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Order [subs] by the active Home sort mode, so refreshes (remote
  /// changes, add/edit/delete) keep the user's chosen order instead of
  /// falling back to Hive box order.
  List<Subscription> _applySortMode(List<Subscription> subs) {
    switch (_ref.read(homeSortModeProvider)) {
      case HomeSortMode.date:
        subs.sort((a, b) => a.nextBillDate.compareTo(b.nextBillDate));
      case HomeSortMode.price:
        subs.sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));
      case HomeSortMode.name:
        subs.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return subs;
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
      subscription.updatedAt = clock.now();
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
      subscription.updatedAt = clock.now();
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
      // Bump updatedAt and push to remote so the change isn't reverted by
      // the remote listener's last-write-wins on next sync tick.
      final updated = _databaseService.getSubscriptionById(id);
      if (updated != null) {
        updated.updatedAt = clock.now();
        await _databaseService.updateSubscription(updated);
        _syncPush(updated);
      }
      await loadSubscriptions();
    } catch (e) {
      rethrow;
    }
  }

  /// Unarchive a subscription
  Future<void> unarchiveSubscription(String id) async {
    try {
      await _databaseService.unarchiveSubscription(id);
      final updated = _databaseService.getSubscriptionById(id);
      if (updated != null) {
        updated.updatedAt = clock.now();
        await _databaseService.updateSubscription(updated);
        _syncPush(updated);
        // Reschedule renewal notifications now that it's active again
        final preferences = _ref.read(preferencesProvider);
        await _notificationService.scheduleSubscriptionNotifications(
          updated,
          preferences,
        );
      }
      await loadSubscriptions();
    } catch (e) {
      rethrow;
    }
  }

  /// Soft-delete a subscription (move to Recently Deleted).
  ///
  /// Cancels its scheduled notifications so a sub sitting in Recently Deleted
  /// no longer fires renewal/trial reminders. Pushes the soft-deleted state
  /// (deletedAt set) to remote — NOT a hard delete — so other devices move it
  /// to their own Recently Deleted instead of losing it entirely. The doc is
  /// hard-deleted from remote only on permanent delete or 30-day purge.
  Future<void> moveToRecentlyDeleted(String id) async {
    try {
      await _notificationService.cancelSubscriptionNotifications(id);
      await _databaseService.moveToRecentlyDeleted(id);
      await loadSubscriptions();
      final softDeleted = _databaseService.getSubscriptionById(id);
      if (softDeleted != null) _syncPush(softDeleted);
    } catch (e) {
      rethrow;
    }
  }

  /// Restore subscription from recently deleted
  Future<void> restoreFromRecentlyDeleted(String id) async {
    try {
      await _databaseService.restoreFromRecentlyDeleted(id);
      await loadSubscriptions();

      // Reschedule notifications and re-push to remote after restoring
      final subscription = _databaseService.getSubscriptionById(id);
      if (subscription != null) {
        final preferences = _ref.read(preferencesProvider);
        await _notificationService.scheduleSubscriptionNotifications(
          subscription,
          preferences,
        );
        _syncPush(subscription);
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

/// How the Home list is currently sorted. Backed by persisted preferences
/// (`AppPreferences.homeSortModeIndex`) so the choice survives app restarts;
/// `loadSubscriptions()` reads this to re-apply the order on every load.
enum HomeSortMode { date, price, name }

final homeSortModeProvider = Provider<HomeSortMode>((ref) {
  final index = ref.watch(preferencesProvider).homeSortModeIndex;
  return HomeSortMode.values[index.clamp(0, HomeSortMode.values.length - 1)];
});

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

/// Provider for spend view mode (my share vs household total)
final spendViewModeProvider = StateProvider<SpendViewMode>((ref) {
  return SpendViewMode.myShare;
});

/// Provider for partner subscriptions (from household sync) — reactive via stream
final partnerSubscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final controller = StreamController<List<Subscription>>()
    ..add(syncService.partnerSubscriptions.value);
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
