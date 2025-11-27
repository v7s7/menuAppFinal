import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/analytics_models.dart';

/// List widget for top products
class TopProductsList extends StatelessWidget {
  final List<ProductPerformance> products;
  final String title;
  final bool isSlowMoving;

  const TopProductsList({
    super.key,
    required this.products,
    required this.title,
    this.isSlowMoving = false,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No products found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3);

    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSlowMoving ? Colors.orange[50] : Colors.blue[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                Icon(
                  isSlowMoving ? Icons.trending_down : Icons.trending_up,
                  color: isSlowMoving ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: isSlowMoving ? Colors.orange[100] : Colors.blue[100],
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isSlowMoving ? Colors.orange[900] : Colors.blue[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  product.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${product.quantitySold} sold in ${product.orderCount} orders',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(product.revenue),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Avg: ${product.averageQuantityPerOrder.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
