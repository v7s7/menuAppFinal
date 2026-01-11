import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/config/slug_routing.dart';
import '../../auth/widgets/login_modal.dart';
import '../../cart/state/cart_controller.dart';
import '../../cart/widgets/cart_sheet.dart';
import '../../sweets/data/sweet.dart';
import '../../sweets/data/sweets_repo.dart';
import '../data/order_models.dart' as om;
import '../data/order_service.dart';

final orderHistoryProvider = StreamProvider.autoDispose<List<om.Order>>((ref) {
  final uid = ref.watch(currentUidProvider);
  final ids = ref.watch(effectiveIdsProvider);

  if (uid == null || ids == null) {
    return const Stream.empty();
  }

  final service = OrderService(
    merchantId: ids.merchantId,
    branchId: ids.branchId,
  );

  return service.watchCustomerOrders(uid);
});

class OrderHistoryPage extends ConsumerWidget {
  const OrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: isLoggedIn ? const _OrderHistoryList() : const _LoggedOutState(),
    );
  }
}

class _OrderHistoryList extends ConsumerWidget {
  const _OrderHistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderHistoryProvider);

    return orders.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              'No orders yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final order = list[index];
            return _OrderTile(order: order);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Failed to load orders. Please try again.'),
      ),
    );
  }
}

class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order});
  final om.Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateText = DateFormat('yMMMd h:mm a').format(order.createdAt);
    final amountText = 'BHD ${order.subtotal.toStringAsFixed(3)}';
    final statusText = order.status.label;
    final fulfillment = order.fulfillmentType.label;

    return ListTile(
      title: Text(order.orderNo.isNotEmpty ? order.orderNo : order.orderId),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$dateText · $fulfillment'),
          Text('Status: $statusText'),
          Text('Total: $amountText'),
        ],
      ),
      trailing: TextButton(
        onPressed: () => _reorder(context, ref, order),
        child: const Text('Reorder'),
      ),
    );
  }
}

class _LoggedOutState extends ConsumerWidget {
  const _LoggedOutState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Please log in to view your orders',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => showLoginModal(context),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }
}

Future<void> _reorder(
  BuildContext context,
  WidgetRef ref,
  om.Order order,
) async {
  final sweetsAsync = ref.read(sweetsStreamProvider);
  final sweets = sweetsAsync.maybeWhen<List<Sweet>?>(
    data: (data) => data,
    orElse: () => null,
  );

  if (sweets == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menu is still loading. Please try again.')),
    );
    return;
  }

  final sweetsById = {for (final s in sweets) s.id: s};
  final cart = ref.read(cartControllerProvider.notifier);

  int added = 0;
  int skipped = 0;

  for (final item in order.items) {
    final sweet = sweetsById[item.productId];
    if (sweet == null) {
      skipped++;
      continue;
    }
    cart.add(sweet, qty: item.qty, note: item.note);
    added++;
  }

  if (added > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to cart${skipped > 0 ? ' (some items skipped)' : ''}')),
    );
    _openCartSheet(context);
  } else if (skipped > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Items unavailable to reorder.')),
    );
  }
}

void _openCartSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const CartSheet(),
  );
}