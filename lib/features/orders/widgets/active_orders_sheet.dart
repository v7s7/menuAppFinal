import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_config.dart';
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
      error: (e, _) {
        // Robust error detection using FirebaseException
        final isIndexBuilding = _isIndexBuildingError(e);
        final errorMessage = _getCleanErrorMessage(e);

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
                if (isIndexBuilding) ...[
                  Icon(
                    Icons.hourglass_empty,
                    size: 48,
                    color: cs.primary.withOpacity(0.7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preparing database index…',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please retry in a few minutes.\nWe\'re setting up your order history.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(activeOrdersStreamProvider);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary),
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: cs.error.withOpacity(0.7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load orders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(activeOrdersStreamProvider);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
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
                        final cfg = ref.read(appConfigProvider);
                        final preservedLocation =
                            (cfg.slug != null && cfg.slug!.trim().isNotEmpty)
                            ? '/s/${cfg.slug!.trim()}'
                            : null;

                        Navigator.of(context).pop(); // Close sheet
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            settings: preservedLocation == null
                                ? null
                                : RouteSettings(name: preservedLocation),
                            builder: (_) =>
                                OrderStatusPage(orderId: orders[i].orderId),
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
        final addr = order.customerAddress;
        if (addr != null) {
          final home = (addr.home ?? '').trim();
          final road = (addr.road ?? '').trim();
          if (home.isEmpty && road.isEmpty) return 'Delivery';
          if (home.isEmpty) return 'Delivery: $road';
          if (road.isEmpty) return 'Delivery: $home';
          return 'Delivery: $home, $road';
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

    return Icon(iconData, size: 14, color: cs.onSurface.withOpacity(0.6));
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

// ============================================================================
// Helper Functions for Error Handling
// ============================================================================

/// Detects if the error is a Firestore index building error
bool _isIndexBuildingError(Object error) {
  // Check if it's a FirebaseException with failed-precondition code
  if (error is FirebaseException) {
    if (error.code == 'failed-precondition') {
      final msg = error.message?.toLowerCase() ?? '';
      return msg.contains('index') ||
          msg.contains('requires an index') ||
          msg.contains('currently building');
    }
  }

  // Fallback: check error string for index-related messages
  final errorStr = error.toString().toLowerCase();
  return errorStr.contains('failed-precondition') &&
      (errorStr.contains('index') ||
          errorStr.contains('requires an index') ||
          errorStr.contains('currently building'));
}

/// Extracts a clean, user-friendly error message
String _getCleanErrorMessage(Object error) {
  if (error is FirebaseException) {
    // Map common Firebase error codes to friendly messages
    switch (error.code) {
      case 'permission-denied':
        return 'Access denied. Please sign in and try again.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please check your connection.';
      case 'unauthenticated':
        return 'Please sign in to view your orders.';
      case 'not-found':
        return 'Orders not found. Please try again later.';
      case 'failed-precondition':
        // Should be caught by _isIndexBuildingError, but just in case
        return 'Database is being prepared. Please retry in a moment.';
      default:
        // Return the message if available, otherwise the code
        return error.message ?? 'Error: ${error.code}';
    }
  }

  // For non-Firebase exceptions, extract useful info without stack trace
  final errorStr = error.toString();

  // Remove stack traces (anything after newline)
  final firstLine = errorStr.split('\n').first;

  // Remove exception type prefix (e.g., "Exception: " or "StateError: ")
  final cleaned = firstLine.replaceFirst(RegExp(r'^[A-Z]\w+Error:\s*'), '')
                           .replaceFirst(RegExp(r'^[A-Z]\w+Exception:\s*'), '')
                           .trim();

  // Return cleaned message or fallback
  return cleaned.isNotEmpty
      ? cleaned
      : 'An unexpected error occurred. Please try again.';
}
