import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../models/enums.dart';
import '../models/exchange_rate.dart';
import '../providers/budget_providers.dart';
import '../providers/currency_providers.dart';
import '../providers/subscription_providers.dart';
import '../widgets/budget/budget_progress_bar.dart';

class BudgetSettingsScreen extends ConsumerStatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  ConsumerState<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends ConsumerState<BudgetSettingsScreen> {
  final _overallBudgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(budgetSettingsProvider);
    if (settings.overallMonthlyBudget != null) {
      _overallBudgetController.text = settings.overallMonthlyBudget!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _overallBudgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(budgetSettingsProvider);
    final budgetStatus = ref.watch(budgetStatusProvider);
    final usage = ref.watch(budgetUsageProvider);
    final remaining = ref.watch(remainingBudgetProvider);
    final totalSpend = ref.watch(totalMonthlySpendProvider);
    final categorySpend = ref.watch(categorySpendProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final currencySymbol = CurrencyInfo.getSymbol(displayCurrency);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Status Card
          if (settings.hasBudget) ...[
            _buildStatusCard(
              context,
              settings,
              budgetStatus,
              usage ?? 0,
              remaining,
              totalSpend,
              currencySymbol,
            ),
            const SizedBox(height: 24),
          ],

          // Overall Budget Section
          Text(
            'Monthly Budget',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set a limit for your total monthly subscriptions',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Budget Input
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _overallBudgetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Budget Amount',
                      prefixText: '$currencySymbol ',
                      hintText: '0.00',
                      suffixIcon: settings.hasBudget
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _overallBudgetController.clear();
                                ref.read(budgetSettingsProvider.notifier).setOverallBudget(null);
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (value) => _saveBudget(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saveBudget,
                      child: Text(
                        settings.hasBudget ? 'Update Budget' : 'Set Budget',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Alert Settings Section
          Text(
            'Alert Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Get notified when approaching your budget limit',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Budget Alerts'),
                  subtitle: const Text('Notify when approaching or exceeding budget'),
                  value: settings.budgetAlertsEnabled,
                  onChanged: (value) {
                    ref.read(budgetSettingsProvider.notifier).toggleAlerts(value);
                  },
                ),
                if (settings.budgetAlertsEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Warning Threshold'),
                    subtitle: Text('Alert at ${(settings.warningThreshold * 100).toInt()}% of budget'),
                    trailing: SizedBox(
                      width: 150,
                      child: Slider(
                        value: settings.warningThreshold,
                        min: 0.5,
                        max: 0.95,
                        divisions: 9,
                        label: '${(settings.warningThreshold * 100).toInt()}%',
                        onChanged: (value) {
                          ref.read(budgetSettingsProvider.notifier).setWarningThreshold(value);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Category Budgets Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Budgets',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set limits per category',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category list
          ...SubscriptionCategory.values.map((category) {
            final spend = categorySpend[category.displayName] ?? 0.0;
            final categoryBudget = settings.getCategoryBudget(category.displayName);
            final hasSpend = spend > 0;

            return _buildCategoryBudgetCard(
              context,
              category,
              spend,
              categoryBudget,
              hasSpend,
              currencySymbol,
            );
          }),

          const SizedBox(height: 32),

          // Clear All
          Center(
            child: TextButton.icon(
              onPressed: () => _showClearDialog(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear All Budgets'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _saveBudget() {
    final text = _overallBudgetController.text.trim();
    if (text.isEmpty) {
      ref.read(budgetSettingsProvider.notifier).setOverallBudget(null);
    } else {
      final amount = double.tryParse(text);
      if (amount != null && amount > 0) {
        ref.read(budgetSettingsProvider.notifier).setOverallBudget(amount);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget updated')),
        );
      }
    }
    FocusScope.of(context).unfocus();
  }

  Widget _buildStatusCard(
    BuildContext context,
    BudgetSettings settings,
    BudgetStatus status,
    double usage,
    double? remaining,
    double totalSpend,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);

    Color statusColor;
    switch (status) {
      case BudgetStatus.safe:
        statusColor = theme.colorScheme.secondary;
        break;
      case BudgetStatus.warning:
        statusColor = theme.colorScheme.tertiary;
        break;
      case BudgetStatus.exceeded:
        statusColor = theme.colorScheme.error;
        break;
      case BudgetStatus.noBudget:
        statusColor = theme.colorScheme.outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.15),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Month',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.displayName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currencySymbol${totalSpend.toStringAsFixed(2)}',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'of $currencySymbol${settings.overallMonthlyBudget!.toStringAsFixed(0)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BudgetProgressBar(
            usage: usage,
            status: status,
            showLabel: false,
          ),
          const SizedBox(height: 12),
          if (remaining != null)
            Text(
              remaining >= 0
                  ? '$currencySymbol${remaining.toStringAsFixed(2)} remaining'
                  : '$currencySymbol${remaining.abs().toStringAsFixed(2)} over budget',
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetCard(
    BuildContext context,
    SubscriptionCategory category,
    double spend,
    double? budget,
    bool hasSpend,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final hasBudget = budget != null && budget > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              category.icon,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        title: Text(
          category.displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: hasSpend || hasBudget
            ? Text(
                hasBudget
                    ? '$currencySymbol${spend.toStringAsFixed(2)} / $currencySymbol${budget.toStringAsFixed(0)}'
                    : '$currencySymbol${spend.toStringAsFixed(2)} spent',
              )
            : const Text('No subscriptions'),
        trailing: TextButton(
          onPressed: () => _showCategoryBudgetDialog(context, category, budget, currencySymbol),
          child: Text(hasBudget ? 'Edit' : 'Set'),
        ),
      ),
    );
  }

  void _showCategoryBudgetDialog(
    BuildContext context,
    SubscriptionCategory category,
    double? currentBudget,
    String currencySymbol,
  ) {
    final controller = TextEditingController(
      text: currentBudget?.toStringAsFixed(0) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${category.displayName} Budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: 'Monthly Limit',
            prefixText: '$currencySymbol ',
            hintText: '0.00',
          ),
          autofocus: true,
        ),
        actions: [
          if (currentBudget != null)
            TextButton(
              onPressed: () {
                ref.read(budgetSettingsProvider.notifier).setCategoryBudget(
                      category.displayName,
                      null,
                    );
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim());
              ref.read(budgetSettingsProvider.notifier).setCategoryBudget(
                    category.displayName,
                    amount,
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Budgets?'),
        content: const Text(
          'This will remove all budget limits. Your subscription data will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(budgetSettingsProvider.notifier).clearAllBudgets();
              _overallBudgetController.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All budgets cleared')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
