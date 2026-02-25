import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../models/exchange_rate.dart';
import '../models/sync_status.dart';
import '../providers/auth_providers.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../providers/currency_providers.dart';
import '../providers/household_providers.dart';
import '../providers/subscription_providers.dart';
import '../providers/sync_providers.dart';
import '../providers/theme_providers.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import 'auth_screen.dart';
import 'budget_settings_screen.dart';
import 'category_management_screen.dart';
import 'household_screen.dart';
import 'notification_settings_screen.dart';
import 'profile_screen.dart';
import 'theme_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentPreset = ref.watch(currentPresetProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        automaticallyImplyLeading: false, // Remove back button since it's a main tab
        title: Text(
          'Settings',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App Section
          _buildSectionHeader(context, 'App'),
          _buildSettingCard(
            context,
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: currentPreset.name,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ThemeSettingsScreen(),
                ),
              );
            },
          ),
          _buildSettingCard(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage renewal reminders',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          _buildBudgetCard(context, ref),
          _buildCategoriesCard(context, ref),
          _buildCurrencyCard(context, ref),

          const SizedBox(height: 24),

          // Account Section
          _buildSectionHeader(context, 'Account'),
          _buildAuthCard(context, ref),
          _buildSyncCard(context, ref),
          _buildHouseholdNavCard(context, ref),

          const SizedBox(height: 24),

          // Data Section
          _buildSectionHeader(context, 'Data'),
          _buildSettingCard(
            context,
            icon: Icons.cloud_download_outlined,
            title: 'Export Data',
            subtitle: 'Download your subscriptions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export feature coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _buildSettingCard(
            context,
            icon: Icons.delete_outline,
            title: 'Clear All Data',
            subtitle: 'Delete all subscriptions',
            onTap: () => _showClearDataDialog(context, ref),
            isDestructive: true,
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader(context, 'About'),
          _buildSettingCard(
            context,
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: AppConstants.appVersion,
            onTap: null,
          ),
          _buildSettingCard(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy policy coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _buildSettingCard(
            context,
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Help us improve',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bug reporting coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: isDestructive ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive ? theme.colorScheme.error : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: trailing ??
            (onTap != null
                ? Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  )
                : null),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(budgetSettingsProvider);
    final status = ref.watch(budgetStatusProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final currencySymbol = CurrencyInfo.getSymbol(displayCurrency);

    String subtitle;
    Widget? trailing;

    if (settings.hasBudget) {
      subtitle = '$currencySymbol${settings.overallMonthlyBudget!.toStringAsFixed(0)}/month';
      if (status == BudgetStatus.warning || status == BudgetStatus.exceeded) {
        trailing = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: status == BudgetStatus.exceeded
                ? theme.colorScheme.error.withValues(alpha: 0.15)
                : theme.colorScheme.tertiary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.displayName,
            style: TextStyle(
              color: status == BudgetStatus.exceeded
                  ? theme.colorScheme.error
                  : theme.colorScheme.tertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
    } else {
      subtitle = 'Set spending limits';
    }

    return _buildSettingCard(
      context,
      icon: Icons.account_balance_wallet_outlined,
      title: 'Budget',
      subtitle: subtitle,
      trailing: trailing,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BudgetSettingsScreen(),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesCard(BuildContext context, WidgetRef ref) {
    final customCount = ref.watch(customCategoriesCountProvider);
    final subtitle = customCount > 0
        ? '$customCount custom ${customCount == 1 ? 'category' : 'categories'}'
        : 'Manage subscription categories';

    return _buildSettingCard(
      context,
      icon: Icons.category_outlined,
      title: 'Categories',
      subtitle: subtitle,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CategoryManagementScreen(),
          ),
        );
      },
    );
  }

  Widget _buildCurrencyCard(BuildContext context, WidgetRef ref) {
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final currencyInfo = CurrencyInfo.getByCode(displayCurrency);
    final ratesAsync = ref.watch(exchangeRatesProvider);

    String subtitle = currencyInfo != null
        ? '${currencyInfo.flag} ${currencyInfo.name}'
        : displayCurrency;

    // Show last update status
    ratesAsync.whenData((rates) {
      if (rates != null && rates.isStale) {
        subtitle += ' • Rates outdated';
      }
    });

    return _buildSettingCard(
      context,
      icon: Icons.currency_exchange,
      title: 'Display Currency',
      subtitle: subtitle,
      onTap: () => _showCurrencyPicker(context, ref),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentCurrency = ref.read(displayCurrencyProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Display Currency',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Currency list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: CurrencyInfo.all.length,
                    itemBuilder: (context, index) {
                      final currency = CurrencyInfo.all[index];
                      final isSelected = currency.code == currentCurrency;

                      return ListTile(
                        leading: Text(
                          currency.flag ?? '',
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          currency.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('${currency.code} • ${currency.symbol}'),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                            : null,
                        onTap: () {
                          ref.read(displayCurrencyProvider.notifier).setCurrency(currency.code);
                          Navigator.pop(context);
                          // Refresh exchange rates if needed
                          ref.read(refreshRatesProvider)();
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAuthCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSignedIn = ref.watch(isSignedInProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);

    if (isSignedIn) {
      final profile = profileAsync.value;
      return _buildSettingCard(
        context,
        icon: Icons.person,
        title: profile?.displayName ?? 'Profile',
        subtitle: profile?.email ?? 'Signed in',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        },
        trailing: profile?.isPro == true
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Free',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      );
    }

    return _buildSettingCard(
      context,
      icon: Icons.person_outline,
      title: 'Sign In',
      subtitle: 'Sync data across devices',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      },
    );
  }

  Widget _buildSyncCard(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) return const SizedBox.shrink();

    final syncStatus = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;

    String subtitle;
    switch (syncStatus) {
      case SyncStatus.synced:
        subtitle = 'All data synced';
      case SyncStatus.syncing:
        subtitle = 'Syncing...';
      case SyncStatus.error:
        subtitle = 'Sync error — tap to retry';
      case SyncStatus.offline:
        subtitle = 'Offline — will sync when connected';
      default:
        subtitle = 'Cloud sync';
    }

    return _buildSettingCard(
      context,
      icon: syncStatus == SyncStatus.synced
          ? Icons.cloud_done_outlined
          : syncStatus == SyncStatus.error
              ? Icons.cloud_off_outlined
              : Icons.cloud_sync_outlined,
      title: 'Cloud Sync',
      subtitle: subtitle,
      onTap: syncStatus == SyncStatus.error
          ? () {
              final user = ref.read(currentFirebaseUserProvider);
              if (user != null) {
                ref.read(syncServiceProvider).forceSync(user.uid);
              }
            }
          : null,
    );
  }

  Widget _buildHouseholdNavCard(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) return const SizedBox.shrink();

    final householdAsync = ref.watch(currentHouseholdProvider);
    final household = householdAsync.value;

    return _buildSettingCard(
      context,
      icon: Icons.people_outline,
      title: 'Household',
      subtitle: household != null
          ? '${household.name} (${household.members.length} members)'
          : 'Create or join a household',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HouseholdScreen()),
        );
      },
    );
  }

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Clear all data?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will permanently delete:'),
              const SizedBox(height: 12),
              _buildBullet(theme, 'All your subscriptions'),
              _buildBullet(theme, 'Cloud synced data'),
              _buildBullet(theme, 'Split proposals'),
              _buildBullet(theme, 'Scheduled notifications'),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showFinalConfirmation(context, ref);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _showFinalConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: const Text(
            'All data will be permanently erased. '
            'You will not be able to recover it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Go Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _clearAllData(context, ref);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Delete Everything'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('  •  ', style: TextStyle(color: theme.colorScheme.error)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    try {
      final db = DatabaseService();
      final notificationService = NotificationService();

      // Cancel all notifications
      await notificationService.cancelAllNotifications();

      // Delete from Firestore if signed in
      final user = ref.read(currentFirebaseUserProvider);
      if (user != null) {
        final firestore = FirebaseFirestore.instance;
        final subsSnapshot = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('subscriptions')
            .get();
        for (final doc in subsSnapshot.docs) {
          await doc.reference.delete();
        }

        // Also clear split proposals
        final proposalsSnapshot = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('split_proposals')
            .get();
        for (final doc in proposalsSnapshot.docs) {
          await doc.reference.delete();
        }
      }

      // Clear local Hive data
      await db.deleteAllSubscriptions();

      // Dispose sync listeners so they don't re-add deleted subs
      SyncService().dispose();

      // Re-initialize sync if signed in
      if (user != null) {
        await SyncService().initialize(user.uid);
      }

      // Reload UI
      ref.read(subscriptionProvider.notifier).loadSubscriptions();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear data: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
