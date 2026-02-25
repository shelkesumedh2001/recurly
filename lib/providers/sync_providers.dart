import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_status.dart';
import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'auth_providers.dart';
import 'currency_providers.dart';
import 'subscription_providers.dart';

/// Provider for the sync service singleton
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

/// Provider for sync status — reactive via stream from ValueNotifier
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  // Convert ValueNotifier to Stream for reactivity
  final controller = StreamController<SyncStatus>();
  controller.add(syncService.syncStatus.value);
  void listener() {
    if (!controller.isClosed) {
      controller.add(syncService.syncStatus.value);
    }
  }
  syncService.syncStatus.addListener(listener);
  ref.onDispose(() {
    syncService.syncStatus.removeListener(listener);
    controller.close();
  });
  return controller.stream;
});

/// Provider for whether sync is enabled (signed in)
final isSyncEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isSignedInProvider);
});

/// Reactive sync initialization — auto-initializes sync when user signs in
final syncInitProvider = Provider<void>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  final syncService = ref.watch(syncServiceProvider);

  if (user == null) return;

  // Initialize sync (pulls data from Firestore into Hive)
  syncService.initialize(user.uid).then((_) {
    // Force reload subscriptions after sync completes
    ref.read(subscriptionProvider.notifier).loadSubscriptions();
    debugPrint('Sync initialized reactively for ${user.uid}');

    // Auto-detect display currency if it doesn't match any subscription currency
    final currentCurrency = ref.read(displayCurrencyProvider);
    final subs = DatabaseService().getActiveSubscriptions();
    if (subs.isNotEmpty) {
      final subCurrencies = subs.map((s) => s.currency).toSet();
      if (!subCurrencies.contains(currentCurrency)) {
        // Display currency doesn't match any subscription — switch to most common
        final counts = <String, int>{};
        for (final sub in subs) {
          counts[sub.currency] = (counts[sub.currency] ?? 0) + 1;
        }
        final sorted = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final detected = sorted.first.key;
        ref.read(displayCurrencyProvider.notifier).setCurrency(detected);
        debugPrint('Auto-set display currency to $detected after sync');
      }
    }

    // Fetch exchange rates so currency conversion works
    CurrencyService().getRates().then((_) {
      // Invalidate to trigger UI rebuild with rates
      ref.invalidate(exchangeRatesProvider);
    });
  });
});

/// Reactive household sync provider — auto-initializes/disposes when householdId changes
final householdSyncProvider = Provider<void>((ref) {
  final profile = ref.watch(currentUserProfileProvider).value;
  final user = ref.watch(currentFirebaseUserProvider);
  final syncService = ref.watch(syncServiceProvider);

  if (user == null || profile == null || profile.householdId == null) {
    syncService.disposeHouseholdSync();
    return;
  }

  final householdId = profile.householdId!;
  final uid = user.uid;

  // Initialize household sync
  syncService.initializeHouseholdSync(uid, householdId);

  ref.onDispose(() {
    syncService.disposeHouseholdSync();
  });
});
