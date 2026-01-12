import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_providers.dart';
import '../providers/subscription_providers.dart';
import '../utils/constants.dart';
import '../widgets/analytics/category_pie_chart.dart';
import '../widgets/analytics/spending_trend_chart.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final totalMonthlySpend = ref.watch(totalMonthlySpendProvider);
    final yearlyProjected = ref.watch(yearlyProjectedSpendProvider);
    final mostExpensive = ref.watch(mostExpensiveSubscriptionProvider);
    final topCategory = ref.watch(topCategoryProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Analytics'),
        automaticallyImplyLeading: false, // Remove back button since it's a main tab
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Stats
            _buildHeroStats(theme, totalMonthlySpend, yearlyProjected),
            
            const SizedBox(height: 32),

            // Spending Trend Chart (New)
            Text(
              'Projected Spending',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SpendingTrendChart(),
              ),
            ),

            const SizedBox(height: 32),
            
            // Category Chart
            Text(
              'Spending by Category',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CategoryPieChart(),
              ),
            ),

            const SizedBox(height: 32),

            // Insights Section
            Text(
              'Insights',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildInsightCard(
              theme,
              title: 'Most Expensive',
              value: mostExpensive?.name ?? 'None',
              subtitle: mostExpensive?.formattedPrice ?? '-',
              icon: Icons.trending_up,
              color: theme.colorScheme.error,
            ),
            if (topCategory != null) ...[
              const SizedBox(height: 12),
              _buildInsightCard(
                theme,
                title: 'Top Category',
                value: topCategory.key.displayName,
                subtitle: '\$${topCategory.value.toStringAsFixed(2)}/mo',
                icon: Icons.pie_chart,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStats(ThemeData theme, double monthly, double yearly) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            label: 'Monthly',
            value: '\$${monthly.toStringAsFixed(0)}',
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            theme,
            label: 'Yearly',
            value: '\$${yearly.toStringAsFixed(0)}',
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, {required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
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
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
