import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/budget_providers.dart';
import '../../providers/currency_providers.dart';
import '../../screens/budget_settings_screen.dart';
import 'budget_alert_card.dart';

/// Home's budget alert (P3-2): shown when "Budget alerts" is on and this
/// month's spend (my share) reaches the warning threshold or the budget.
/// Dismissing hides it for a day; tapping opens the budget screen.
class BudgetAlertBanner extends ConsumerWidget {
  const BudgetAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(shouldShowBudgetAlertProvider)) {
      return const SizedBox.shrink();
    }
    final settings = ref.watch(budgetSettingsProvider);
    final budget = settings.overallMonthlyBudget;
    if (budget == null || budget <= 0) return const SizedBox.shrink();

    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    return BudgetAlertCard(
      status: ref.watch(budgetStatusProvider),
      usage: ref.watch(budgetUsageProvider) ?? 0,
      budget: budget,
      spent: ref.watch(convertedTotalSpendProvider),
      formatAmount: (v) => currencyService.formatAmount(v, displayCurrency),
      onDismiss: () =>
          ref.read(budgetSettingsProvider.notifier).dismissAlert(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BudgetSettingsScreen()),
      ),
    );
  }
}
