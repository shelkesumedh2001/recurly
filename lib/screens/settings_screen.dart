import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../models/exchange_rate.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../providers/currency_providers.dart';
import '../providers/theme_providers.dart';
import '../utils/constants.dart';
import 'budget_settings_screen.dart';
import 'category_management_screen.dart';
import 'notification_settings_screen.dart';
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
          _buildSettingCard(
            context,
            icon: Icons.person_outline,
            title: 'Pro Subscription',
            subtitle: 'Unlock unlimited subscriptions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pro upgrade coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            trailing: Container(
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
          ),
          _buildSettingCard(
            context,
            icon: Icons.share_outlined,
            title: 'Share with Family',
            subtitle: 'Coming soon',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Family sharing coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

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
            onTap: () => _showClearDataDialog(context),
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

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Clear all data?'),
          content: const Text(
            'This will permanently delete all your subscriptions. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This feature will be implemented soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }
}
