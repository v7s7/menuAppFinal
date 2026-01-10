import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/order_models.dart' as om;
import '../data/active_orders_service.dart';
import '../screens/order_status_page.dart';

/// Bottom sheet showing customer's active orders
class ActiveOrdersSheet extends ConsumerWidget {
  const ActiveOrdersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(activeOrdersStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return ordersAsync.when(
      loading: () => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              const SizedBox(height: 12),
              const Text(
                'Active Orders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      error: (e, _) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              const SizedBox(height: 12),
              const Text(
                'Active Orders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              Text(
                'Error loading orders',
                style: TextStyle(color: cs.error),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(),
                  const SizedBox(height: 12),
                  const Text(
                    'Active Orders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No active orders',
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Active Orders',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      '${orders.length} order${orders.length == 1 ? '' : 's'}',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Order list with max height
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _OrderCard(
                      order: orders[i],
                      onTap: () {
                        Navigator.of(context).pop(); // Close sheet
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderStatusPage(orderId: orders[i].orderId),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final om.Order order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    order.orderNo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _FulfillmentIcon(type: order.fulfillmentType),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getFulfillmentDetail(order),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${order.subtotal.toStringAsFixed(3)} BHD',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFulfillmentDetail(om.Order order) {
    switch (order.fulfillmentType) {
      case om.FulfillmentType.carPickup:
        return 'Car: ${order.customerCarPlate ?? 'N/A'}';
      case om.FulfillmentType.delivery:
        if (order.customerAddress != null) {
          final addr = order.customerAddress!;
          return 'Delivery: ${addr['home'] ?? ''}, ${addr['road'] ?? ''}';
        }
        return 'Delivery';
      case om.FulfillmentType.dineIn:
        return 'Table: ${order.table ?? 'N/A'}';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final om.OrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: config.color,
        ),
      ),
    );
  }

  ({String label, Color color}) _getStatusConfig(om.OrderStatus status) {
    switch (status) {
      case om.OrderStatus.pending:
        return (label: 'Pending', color: Colors.orange);
      case om.OrderStatus.accepted:
        return (label: 'Accepted', color: Colors.blue);
      case om.OrderStatus.preparing:
        return (label: 'Preparing', color: Colors.purple);
      case om.OrderStatus.ready:
        return (label: 'Ready', color: Colors.green);
      case om.OrderStatus.served:
        return (label: 'Served', color: Colors.grey);
      case om.OrderStatus.cancelled:
        return (label: 'Cancelled', color: Colors.red);
    }
  }
}

class _FulfillmentIcon extends StatelessWidget {
  final om.FulfillmentType type;

  const _FulfillmentIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconData = _getIcon();

    return Icon(
      iconData,
      size: 14,
      color: cs.onSurface.withOpacity(0.6),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case om.FulfillmentType.carPickup:
        return Icons.directions_car;
      case om.FulfillmentType.delivery:
        return Icons.local_shipping;
      case om.FulfillmentType.dineIn:
        return Icons.restaurant;
    }
  }
}
