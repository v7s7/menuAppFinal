import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/analytics_models.dart';

/// Customer insights summary card
class CustomerInsightsCard extends StatelessWidget {
  final CustomerInsights insights;

  const CustomerInsightsCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Customer Metrics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    context,
                    'Total Customers',
                    insights.totalCustomers.toString(),
                    Icons.person,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    context,
                    'New Customers',
                    insights.newCustomers.toString(),
                    Icons.person_add,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    context,
                    'Returning',
                    insights.returningCustomers.toString(),
                    Icons.repeat,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    context,
                    'Retention Rate',
                    '${insights.customerRetentionRate}%',
                    Icons.trending_up,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    context,
                    'Avg Orders/Customer',
                    insights.averageOrdersPerCustomer.toString(),
                    Icons.shopping_cart,
                    Colors.teal,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    context,
                    'Lifetime Value',
                    currencyFormat.format(insights.averageLifetimeValue),
                    Icons.attach_money,
                    Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
