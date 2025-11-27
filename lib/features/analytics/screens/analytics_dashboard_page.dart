import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/analytics_models.dart';
import '../data/analytics_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/revenue_chart.dart';
import '../widgets/hourly_chart.dart';
import '../widgets/top_products_list.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/customer_insights_card.dart';

/// State provider for selected date range
final selectedDateRangeProvider = StateProvider<DateRange>((ref) => DateRange.last7Days);

/// Main analytics dashboard page for merchants
class AnalyticsDashboardPage extends ConsumerWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(selectedDateRangeProvider);
    final analyticsAsync = ref.watch(analyticsDashboardProvider(selectedRange));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _DateRangeSelector(
            selectedRange: selectedRange,
            onRangeChanged: (range) {
              ref.read(selectedDateRangeProvider.notifier).state = range;
            },
          ),
        ),
      ),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading analytics: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(analyticsDashboardProvider(selectedRange)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (dashboard) => _buildDashboard(context, dashboard),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, AnalyticsDashboard dashboard) {
    if (dashboard.sales.totalOrders == 0) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No data for this period',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Orders will appear here once customers start ordering',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key metrics overview
          _SectionHeader(
            title: 'Sales Overview',
            subtitle: _formatDateRange(dashboard.startDate, dashboard.endDate),
          ),
          const SizedBox(height: 16),
          _buildKeyMetrics(dashboard.sales),
          const SizedBox(height: 32),

          // Revenue trend
          const _SectionHeader(title: 'Revenue Trend'),
          const SizedBox(height: 16),
          RevenueChart(trends: dashboard.dailyTrends),
          const SizedBox(height: 32),

          // Hourly distribution
          const _SectionHeader(title: 'Peak Hours'),
          const SizedBox(height: 16),
          HourlyChart(distribution: dashboard.hourlyDistribution),
          const SizedBox(height: 32),

          // Customer insights
          const _SectionHeader(title: 'Customer Insights'),
          const SizedBox(height: 16),
          CustomerInsightsCard(insights: dashboard.customerInsights),
          const SizedBox(height: 32),

          // Product performance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'Top Selling Products'),
                    const SizedBox(height: 16),
                    TopProductsList(
                      products: dashboard.topProducts,
                      title: 'Best Sellers',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'Slow Moving Products'),
                    const SizedBox(height: 16),
                    TopProductsList(
                      products: dashboard.slowMovingProducts,
                      title: 'Need Attention',
                      isSlowMoving: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Category breakdown
          const _SectionHeader(title: 'Category Performance'),
          const SizedBox(height: 16),
          CategoryBreakdownChart(categories: dashboard.categoryPerformance),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(SalesAnalytics sales) {
    final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3);

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        StatCard(
          title: 'Total Revenue',
          value: currencyFormat.format(sales.totalRevenue),
          icon: Icons.monetization_on,
          color: Colors.green,
        ),
        StatCard(
          title: 'Total Orders',
          value: sales.totalOrders.toString(),
          icon: Icons.shopping_bag,
          color: Colors.blue,
        ),
        StatCard(
          title: 'Average Order Value',
          value: currencyFormat.format(sales.averageOrderValue),
          icon: Icons.attach_money,
          color: Colors.orange,
        ),
        StatCard(
          title: 'Completion Rate',
          value: '${sales.completionRate}%',
          subtitle: '${sales.completedOrders} completed, ${sales.cancelledOrders} cancelled',
          icon: Icons.check_circle,
          color: Colors.purple,
        ),
        StatCard(
          title: 'Total Items Sold',
          value: sales.totalItems.toString(),
          icon: Icons.inventory,
          color: Colors.teal,
        ),
      ],
    );
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return '${dateFormat.format(start)} - ${dateFormat.format(end)}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ],
    );
  }
}

class _DateRangeSelector extends StatelessWidget {
  final DateRange selectedRange;
  final ValueChanged<DateRange> onRangeChanged;

  const _DateRangeSelector({
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: DateRange.values.where((r) => r != DateRange.custom).map((range) {
            final isSelected = range == selectedRange;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(range.label),
                selected: isSelected,
                onSelected: (_) => onRangeChanged(range),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
