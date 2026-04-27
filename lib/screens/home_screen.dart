import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exchange_rate.dart';
import '../models/sync_status.dart';
import '../providers/auth_providers.dart';
import '../providers/currency_providers.dart';
import '../providers/household_providers.dart';
import '../providers/split_providers.dart';
import '../providers/subscription_providers.dart';
import '../providers/sync_providers.dart';
import '../services/currency_service.dart';
import '../utils/constants.dart';
import '../widgets/add_subscription_sheet.dart';
import '../widgets/subscription_card.dart';
import '../widgets/sync_indicator.dart';
import 'archived_screen.dart';
import 'recently_deleted_screen.dart';
import 'split_requests_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Subscribe to lifecycle providers for their side effects (sync init,
    // household sync init, stale-household cleanup). Empty listener is
    // intentional — these are Provider<void>; we hold the subscription so
    // they stay alive for the screen's lifetime and re-run when their own
    // dependencies (auth user, profile, household stream) change.
    ref
      ..listenManual(syncInitProvider, (_, __) {})
      ..listenManual(householdSyncProvider, (_, __) {})
      ..listenManual(householdCleanupProvider, (_, __) {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Compute household total with currency conversion
  /// Counts each original subscription at full price, skips reference subs to avoid double-counting
  double _convertedHouseholdTotal(
    WidgetRef ref,
    String displayCurrency,
    ExchangeRateCache? rates,
    CurrencyService currencyService,
  ) {
    final currentUid = ref.watch(currentFirebaseUserProvider)?.uid;
    final ownSubs = ref.watch(subscriptionProvider).value ?? [];
    final partnerSubs = ref.watch(partnerSubscriptionsProvider).value ?? [];

    double total = 0;
    // Own subs: skip reference subs (ownerUid set to someone else)
    for (final sub in ownSubs) {
      if (sub.ownerUid != null && sub.ownerUid != currentUid) continue;
      if (sub.isArchived || sub.deletedAt != null) continue;
      total += currencyService.convert(
        amount: sub.monthlyEquivalent,
        from: sub.currency,
        to: displayCurrency,
        rates: rates,
      );
    }
    // Partner subs: skip their reference subs that point back to us (already counted above)
    for (final sub in partnerSubs) {
      if (sub.ownerUid == currentUid) continue; // reference to our sub, already counted
      if (sub.isArchived || sub.deletedAt != null) continue;
      total += currencyService.convert(
        amount: sub.monthlyEquivalent,
        from: sub.currency,
        to: displayCurrency,
        rates: rates,
      );
    }
    return total;
  }

  /// Compute my share with currency conversion
  double _convertedMyShare(
    WidgetRef ref,
    String displayCurrency,
    ExchangeRateCache? rates,
    CurrencyService currencyService,
  ) {
    final subs = ref.watch(subscriptionProvider).value ?? [];
    double total = 0;
    for (final sub in subs) {
      double amount = sub.monthlyEquivalent;
      if (sub.splitWith != null && sub.splitWith!.isNotEmpty) {
        double myMultiplier = 1.0;
        for (final split in sub.splitWith!) {
          if (split['accepted'] == true) {
            final partnerShare = (split['sharePercent'] as num).toDouble();
            myMultiplier -= partnerShare / 100;
          }
        }
        amount *= myMultiplier;
      }
      total += currencyService.convert(
        amount: amount,
        from: sub.currency,
        to: displayCurrency,
        rates: rates,
      );
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionsAsync = ref.watch(filteredSubscriptionsProvider);
    final spendViewMode = ref.watch(spendViewModeProvider);
    final isInHousehold = ref.watch(isInHouseholdProvider);

    // Reset spend view when no longer in household
    if (!isInHousehold && spendViewMode != SpendViewMode.myShare) {
      Future.microtask(() {
        ref.read(spendViewModeProvider.notifier).state = SpendViewMode.myShare;
      });
    }

    // Compute spend based on view mode — always currency-converted
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final rates = ref.watch(exchangeRatesProvider).value;
    final currencyService = ref.read(currencyServiceProvider);

    final double totalSpend;
    if (isInHousehold && spendViewMode == SpendViewMode.householdTotal) {
      totalSpend = _convertedHouseholdTotal(ref, displayCurrency, rates, currencyService);
    } else if (isInHousehold && spendViewMode == SpendViewMode.myShare) {
      totalSpend = _convertedMyShare(ref, displayCurrency, rates, currencyService);
    } else {
      totalSpend = ref.watch(convertedTotalSpendProvider);
    }
    final formattedTotal = ref.watch(formatCurrencyProvider(totalSpend));
    final subscriptionCount = ref.watch(activeSubscriptionCountProvider);
    final partnerSubs = ref.watch(partnerSubscriptionsProvider).value ?? [];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: _isSearchMode
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search subscriptions...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
              )
            : Text(
                AppConstants.appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
        actions: [
          const SyncIndicator(),
          // Split requests badge
          _buildSplitBadge(context, ref),
          IconButton(
            icon: Icon(_isSearchMode ? Icons.close : Icons.search, size: 24),
            tooltip: _isSearchMode ? 'Close search' : 'Search',
            onPressed: () {
              setState(() {
                _isSearchMode = !_isSearchMode;
                if (!_isSearchMode) {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 24),
            tooltip: 'Menu',
            onPressed: () => _showMenu(context, ref),
          ),
        ],
      ),
      body: subscriptionsAsync.when(
        data: (subscriptions) {
          return RefreshIndicator(
            onRefresh: () async {
              // Reload subscriptions from database
              await ref.read(subscriptionProvider.notifier).loadSubscriptions();
            },
            child: CustomScrollView(
              slivers: [
              // Hero section
              SliverToBoxAdapter(
                child: _buildHeroSection(context, formattedTotal, subscriptionCount),
              ),

              // Subscriptions list or empty state
              if (subscriptions.isEmpty && partnerSubs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context, ref.watch(searchQueryProvider)),
                )
              else ...[
                // Own subscriptions
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SubscriptionCard(
                            subscription: subscriptions[index],
                            showSwipeHint: index == 0,
                          ),
                        );
                      },
                      childCount: subscriptions.length,
                    ),
                  ),
                ),
                // Partner subscriptions (when in household)
                if (isInHousehold &&
                    spendViewMode == SpendViewMode.householdTotal &&
                    partnerSubs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Text(
                        "Partner's Subscriptions",
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SubscriptionCard(
                              subscription: partnerSubs[index],
                              isPartnerSub: true,
                            ),
                          );
                        },
                        childCount: partnerSubs.length,
                      ),
                    ),
                  ),
                ],
              ],

              // Bottom spacing for FAB
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 100),
              ),
            ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error.toString()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSubscriptionSheet(context),
        elevation: 2,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildSplitBadge(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingSplitCountProvider);
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn || count == 0) return const SizedBox.shrink();

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.call_split, size: 22),
          tooltip: 'Split requests',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SplitRequestsScreen(),
              ),
            );
          },
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// Minimal hero section
  Widget _buildHeroSection(BuildContext context, String formattedTotal, int count) {
    final theme = Theme.of(context);
    final isInHousehold = ref.watch(isInHouseholdProvider);
    final spendViewMode = ref.watch(spendViewModeProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isInHousehold
                    ? spendViewMode.displayName
                    : 'Monthly Total',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              if (isInHousehold)
                _buildSpendToggle(context, theme, spendViewMode),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formattedTotal,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count ${count == 1 ? 'subscription' : 'subscriptions'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendToggle(
    BuildContext context,
    ThemeData theme,
    SpendViewMode current,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: SpendViewMode.values.map((mode) {
          final isSelected = mode == current;
          return GestureDetector(
            onTap: () {
              ref.read(spendViewModeProvider.notifier).state = mode;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                mode.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Minimal empty state
  Widget _buildEmptyState(BuildContext context, String searchQuery) {
    final theme = Theme.of(context);

    // Show "no results" if searching
    if (searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off,
                  size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No results found',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Try searching with a different term',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Original empty state for no subscriptions
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No subscriptions yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Track your subscriptions\nand never miss a renewal',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Error state
  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Show add subscription bottom sheet
  void _showAddSubscriptionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddSubscriptionSheet(),
    );
  }

  /// Show menu options
  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    context,
                    icon: Icons.sort,
                    title: 'Sort',
                    subtitle: 'Change order',
                    onTap: () {
                      Navigator.pop(context);
                      _showSortOptions(context, ref);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.archive_outlined,
                    title: 'Archived',
                    subtitle: 'View archived subscriptions',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ArchivedScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.delete_outline,
                    title: 'Recently Deleted',
                    subtitle: 'Restore within 30 days',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecentlyDeletedScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  /// Show sort options
  void _showSortOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Sort by',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSortOption(
                  context,
                  icon: Icons.calendar_today_outlined,
                  title: 'Next Bill Date',
                  onTap: () {
                    ref.read(subscriptionProvider.notifier).sortByDate();
                    Navigator.pop(context);
                  },
                ),
                _buildSortOption(
                  context,
                  icon: Icons.attach_money,
                  title: 'Price',
                  onTap: () {
                    ref.read(subscriptionProvider.notifier).sortByPrice();
                    Navigator.pop(context);
                  },
                ),
                _buildSortOption(
                  context,
                  icon: Icons.sort_by_alpha,
                  title: 'Name',
                  onTap: () {
                    ref.read(subscriptionProvider.notifier).sortByName();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
