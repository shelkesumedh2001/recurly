import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exchange_rate.dart';
import '../models/subscription.dart';
import '../models/sync_status.dart';
import '../providers/auth_providers.dart';
import '../providers/currency_providers.dart';
import '../providers/household_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/split_providers.dart';
import '../providers/subscription_providers.dart';
import '../providers/sync_providers.dart';
import '../services/currency_service.dart';
import '../theme/app_tokens.dart';
import '../utils/changelog.dart';
import '../utils/constants.dart';
import '../utils/money.dart';
import '../utils/review_prompt.dart';
import '../widgets/add_subscription_sheet.dart';
import '../widgets/common/app_bottom_sheet.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/notification_primer.dart';
import '../widgets/rates_warning.dart';
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
    // Show "what's new" sheet once after a version upgrade, then — only
    // once it's closed — consider asking for a review. Sequenced rather
    // than fired together so the two never stack on each other.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showChangelogIfUpdated(context);
      if (!mounted) return;
      await maybeRequestReview(
        ref.read(preferencesProvider),
        activeSubCount: ref.read(activeSubscriptionCountProvider),
        markRequested:
            ref.read(preferencesProvider.notifier).markReviewRequested,
      );
    });
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
    return roundMoney(total);
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
        double myMultiplier = 1;
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
    return roundMoney(total);
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
                        "${ref.watch(partnerLabelProvider)}'s subscriptions",
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
        onPressed: _showAddSubscriptionSheet,
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
          tooltip:
              '$count pending split ${count == 1 ? 'request' : 'requests'}',
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

  /// Hero: monthly spend, subscription count, and what renews next.
  Widget _buildHeroSection(BuildContext context, String formattedTotal, int count) {
    final theme = Theme.of(context);
    final isInHousehold = ref.watch(isInHouseholdProvider);
    final spendViewMode = ref.watch(spendViewModeProvider);
    final nextRenewal = _nextRenewalLine();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        // Soft accent wash that follows the preset's primary color.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.14),
            theme.colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isInHousehold ? spendViewMode.displayName : 'Monthly spend',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              if (isInHousehold)
                _buildSpendToggle(context, theme, spendViewMode),
            ],
          ),
          const SizedBox(height: 12),
          // Scale the amount down to stay on a single line when the value is
          // wide (long totals / high-denomination currencies). Shorter amounts
          // keep the full 48px size.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formattedTotal,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextRenewal == null
                ? '$count ${count == 1 ? 'subscription' : 'subscriptions'}'
                : '$count ${count == 1 ? 'subscription' : 'subscriptions'}'
                    '  ·  $nextRenewal',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const RatesUnavailableWarning(compact: true),
        ],
      ),
    );
  }

  /// "Next: Netflix in 3 days" — surfaces the soonest renewal where the
  /// money actually leaves, right under the total.
  String? _nextRenewalLine() {
    final subs = ref.watch(subscriptionProvider).value;
    if (subs == null || subs.isEmpty) return null;

    Subscription? next;
    for (final sub in subs) {
      if (sub.isArchived || sub.deletedAt != null) continue;
      if (next == null || sub.daysUntilRenewal < next.daysUntilRenewal) {
        next = sub;
      }
    }
    if (next == null) return null;

    final days = next.daysUntilRenewal;
    final when = days == 0
        ? 'today'
        : days == 1
            ? 'tomorrow'
            : 'in $days days';
    return 'next: ${next.name} $when';
  }

  Widget _buildSpendToggle(
    BuildContext context,
    ThemeData theme,
    SpendViewMode current,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: SpendViewMode.values.map((mode) {
          final isSelected = mode == current;
          return Semantics(
            button: true,
            selected: isSelected,
            label: '${mode.displayName} spend view',
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(spendViewModeProvider.notifier).state = mode;
              },
              borderRadius: BorderRadius.circular(AppRadius.sm - 2),
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.fast),
                curve: AppMotion.curve,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                ),
                child: Text(
                  mode.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Empty state — doubles as first-run onboarding for new users.
  Widget _buildEmptyState(BuildContext context, String searchQuery) {
    // No matches while searching
    if (searchQuery.isNotEmpty) {
      return AppEmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'Nothing named "$searchQuery" yet. '
            'Check the spelling or try a shorter name.',
        actionLabel: 'Clear search',
        actionIcon: Icons.close,
        onAction: () {
          _searchController.clear();
          ref.read(searchQueryProvider.notifier).state = '';
        },
      );
    }

    // First run: invite the first subscription and preview what the app
    // does — this is the onboarding, so no separate intro flow.
    return AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'Track your first subscription',
      message: 'Add anything that renews — streaming, cloud storage, '
          'gym — and Recurly reminds you before it bills.',
      actionLabel: 'Add subscription',
      onAction: _showAddSubscriptionSheet,
      footer: const Column(
        children: [
          _FeatureHint(
            icon: Icons.notifications_active_outlined,
            text: 'Reminders before every renewal',
          ),
          SizedBox(height: 12),
          _FeatureHint(
            icon: Icons.hourglass_bottom,
            text: 'Free-trial tracking so you cancel in time',
          ),
          SizedBox(height: 12),
          _FeatureHint(
            icon: Icons.people_outline,
            text: 'Split costs with your household',
          ),
        ],
      ),
    );
  }

  /// Error state
  Widget _buildErrorState(BuildContext context, String error) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: "Couldn't load subscriptions",
      message: error,
      actionLabel: 'Try again',
      actionIcon: Icons.refresh,
      onAction: () =>
          ref.read(subscriptionProvider.notifier).loadSubscriptions(),
    );
  }

  /// Show add subscription bottom sheet. The sheet returns the saved
  /// subscription on add (null on edit or dismiss), which is the cue to
  /// offer reminders — the primer itself decides whether it's due.
  /// Uses the State's own `context` (not a parameter) so the `mounted`
  /// guard below actually covers it across the await.
  Future<void> _showAddSubscriptionSheet() async {
    final added = await showModalBottomSheet<Subscription>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const AddSubscriptionSheet(),
    );
    if (added == null || !mounted) return;
    await maybeShowNotificationPrimer(context, ref, added);
  }

  /// Show menu options
  void _showMenu(BuildContext context, WidgetRef ref) {
    showAppSheet(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetTile(
            icon: Icons.sort,
            title: 'Sort',
            subtitle: 'Change list order',
            onTap: () {
              Navigator.pop(sheetContext);
              _showSortOptions(context, ref);
            },
          ),
          AppSheetTile(
            icon: Icons.archive_outlined,
            title: 'Archived',
            subtitle: 'Paused subscriptions',
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ArchivedScreen(),
                ),
              );
            },
          ),
          AppSheetTile(
            icon: Icons.delete_outline,
            title: 'Recently deleted',
            subtitle: 'Restore within 30 days',
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecentlyDeletedScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Show sort options, marking the active one
  void _showSortOptions(BuildContext context, WidgetRef ref) {
    final current = ref.read(homeSortModeProvider);

    void applySort(HomeSortMode mode) {
      final notifier = ref.read(subscriptionProvider.notifier);
      switch (mode) {
        case HomeSortMode.date:
          notifier.sortByDate();
        case HomeSortMode.price:
          notifier.sortByPrice();
        case HomeSortMode.name:
          notifier.sortByName();
      }
      ref.read(preferencesProvider.notifier).setHomeSortModeIndex(mode.index);
    }

    showAppSheet(
      context,
      title: 'Sort by',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetTile(
            icon: Icons.calendar_today_outlined,
            title: 'Next bill date',
            selected: current == HomeSortMode.date,
            onTap: () {
              applySort(HomeSortMode.date);
              Navigator.pop(sheetContext);
            },
          ),
          AppSheetTile(
            icon: Icons.attach_money,
            title: 'Price',
            selected: current == HomeSortMode.price,
            onTap: () {
              applySort(HomeSortMode.price);
              Navigator.pop(sheetContext);
            },
          ),
          AppSheetTile(
            icon: Icons.sort_by_alpha,
            title: 'Name',
            selected: current == HomeSortMode.name,
            onTap: () {
              applySort(HomeSortMode.name);
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    );
  }
}

/// One line of the empty-state feature preview: quiet icon + short claim.
class _FeatureHint extends StatelessWidget {
  const _FeatureHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.primary.withValues(alpha: 0.65),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}
