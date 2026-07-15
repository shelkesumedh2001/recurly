import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_providers.dart';
import '../providers/currency_providers.dart';
import '../providers/subscription_providers.dart';
import '../services/currency_service.dart';
import '../services/export_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/analytics/budget_gauge.dart';
import '../widgets/analytics/cancel_simulator_sheet.dart';
import '../widgets/analytics/category_pie_chart.dart';
import '../widgets/analytics/monthly_comparison_chip.dart';
import '../widgets/analytics/price_changes_section.dart';
import '../widgets/analytics/renewal_calendar.dart';
import '../widgets/analytics/renewal_forecast_timeline.dart';
import '../widgets/analytics/spending_trend_chart.dart';
import '../widgets/analytics/split_savings_card.dart';
import '../widgets/analytics/subscription_count_chart.dart';
import '../widgets/analytics/who_pays_more_bar.dart';
import '../widgets/rates_warning.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMonthlySpend = ref.watch(convertedTotalSpendProvider);
    final yearlyProjected = totalMonthlySpend * 12;
    final mostExpensive = ref.watch(mostExpensiveSubscriptionProvider);
    final topCategory = ref.watch(topCategoryProvider);
    final subscriptionCount = ref.watch(activeSubscriptionCountProvider);
    final currencyService = ref.watch(currencyServiceProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Analytics'),
        automaticallyImplyLeading: false,
        actions: [
          // Export button
          IconButton(
            icon: _isExporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onSurface,
                    ),
                  )
                : const Icon(Icons.ios_share_rounded),
            tooltip: 'Export data',
            onPressed: _isExporting ? null : () => _showExportOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Currency-conversion warning: every chart below converts to the
          // display currency, so a missing-rates fallback poisons them all.
          const RatesUnavailableWarning(),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
              labelStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Calendar'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Overview tab
                _buildOverviewTab(
                  theme,
                  totalMonthlySpend,
                  yearlyProjected,
                  mostExpensive,
                  topCategory,
                  subscriptionCount,
                  currencyService,
                  displayCurrency,
                ),
                // Calendar tab
                _buildCalendarTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    ThemeData theme,
    double totalMonthlySpend,
    double yearlyProjected,
    dynamic mostExpensive,
    dynamic topCategory,
    int subscriptionCount,
    CurrencyService currencyService,
    String displayCurrency,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Stats
          _buildHeroStats(theme, totalMonthlySpend, yearlyProjected,
              subscriptionCount, currencyService, displayCurrency,),

          // Budget Gauge (self-hides if no budget)
          const BudgetGauge(),

          const SizedBox(height: 28),

          // Subscription Count Chart (line)
          const _SectionTitle(
            'Subscription growth',
            subtitle: 'Active subscriptions over the past year',
          ),
          const _ChartCard(child: SubscriptionCountChart()),

          const SizedBox(height: 28),

          // Category Chart (pie)
          const _SectionTitle('Spending by category'),
          const _ChartCard(child: CategoryPieChart()),

          const SizedBox(height: 28),

          // Spending Trend Chart (bar)
          const _SectionTitle('Projected spending'),
          const _ChartCard(child: SpendingTrendChart()),

          const SizedBox(height: 28),

          // Price Changes Section
          const _SectionTitle(
            'Price changes',
            subtitle: 'How your subscription costs have moved',
          ),
          const PriceChangesSection(),

          const SizedBox(height: 28),

          // Upcoming Renewals Timeline
          const _SectionTitle(
            'Upcoming renewals',
            subtitle: 'Charges in the next 30 days',
          ),
          const RenewalForecastTimeline(),

          const SizedBox(height: 28),

          // Who Pays More (self-hides if not in household)
          const WhoPaysMoresBar(),

          // Insights Section
          const _SectionTitle('Insights'),
          if (mostExpensive != null)
            _buildInsightCard(
              theme,
              title: 'Most expensive',
              value: mostExpensive.name,
              subtitle: mostExpensive.formattedPrice,
              icon: Icons.trending_up_rounded,
              color: AppTokens.of(context).danger,
              onTap: () => showCancelSimulatorSheet(context, mostExpensive),
            ),
          if (topCategory != null) ...[
            const SizedBox(height: 10),
            _buildInsightCard(
              theme,
              title: 'Top category',
              value: topCategory.key.displayName,
              subtitle:
                  '${currencyService.formatAmount(topCategory.value, displayCurrency)}/mo',
              icon: Icons.pie_chart_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],

          // Split Savings (self-hides if not in household or no splits)
          const SplitSavingsCard(),

          // Bottom padding
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCalendarTab(ThemeData theme) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            'Renewal calendar',
            subtitle: 'When each subscription bills this month',
          ),
          SizedBox(height: 8),
          RenewalCalendar(),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeroStats(
    ThemeData theme,
    double monthly,
    double yearly,
    int count,
    CurrencyService currencyService,
    String displayCurrency,
  ) {
    return Column(
      children: [
        // Main stat - Monthly spend with gradient background
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTokens.of(context).danger.withValues(alpha: 0.15),
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTokens.of(context).danger.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly spending',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currencyService.formatAmount(monthly, displayCurrency),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTokens.of(context).danger,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count active subscriptions',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              const MonthlyComparisonChip(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Secondary stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                label: 'Yearly',
                value: currencyService.formatAmount(yearly, displayCurrency),
                color: AppTokens.of(context).success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                label: 'Daily average',
                value:
                    currencyService.formatAmount(monthly / 30, displayCurrency),
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          // Scale down to keep the amount on one line in the narrow
          // half-width stat cards (long totals / high-denomination
          // currencies would otherwise wrap).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    ThemeData theme, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Export data',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildExportOption(
                context,
                icon: Icons.table_chart_rounded,
                title: 'Export as CSV',
                subtitle: 'Spreadsheet format for Excel, Numbers, etc.',
                onTap: () async {
                  Navigator.pop(context);
                  await _exportCsv();
                },
              ),
              _buildExportOption(
                context,
                icon: Icons.picture_as_pdf_rounded,
                title: 'Export as PDF',
                subtitle: 'Formatted report with charts and insights',
                onTap: () async {
                  Navigator.pop(context);
                  await _exportPdf();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);

    try {
      final subscriptions = ref.read(subscriptionProvider).value ?? [];
      final displayCurrency = ref.read(displayCurrencyProvider);
      final currencyService = ref.read(currencyServiceProvider);
      final exchangeRates = ref.read(exchangeRatesProvider).value;

      await ExportService().exportToCsv(
        subscriptions,
        displayCurrency: displayCurrency,
        currencyService: currencyService,
        exchangeRates: exchangeRates,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);

    try {
      final subscriptions = ref.read(subscriptionProvider).value ?? [];
      final totalMonthly = ref.read(convertedTotalSpendProvider);
      final displayCurrency = ref.read(displayCurrencyProvider);
      final currencyService = ref.read(currencyServiceProvider);
      final exchangeRates = ref.read(exchangeRatesProvider).value;

      // Get category spend (already in Map<SubscriptionCategory, double> format)
      final categorySpend = ref.read(categorySpendProvider);

      await ExportService().exportToPdf(
        subscriptions,
        totalMonthlySpend: totalMonthly,
        categorySpend: categorySpend,
        displayCurrency: displayCurrency,
        currencyService: currencyService,
        exchangeRates: exchangeRates,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

/// Section heading with the screen's standard 28/4/12 rhythm.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Soft surface container all charts sit in. A large radius + hairline
/// border + diffuse shadow so the card floats rather than reading as a
/// hard-edged box.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
