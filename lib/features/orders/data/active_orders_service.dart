import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'order_models.dart' as om;
import '../../../core/config/slug_routing.dart' show effectiveIdsProvider;
import '../../../core/models/bahrain_address.dart';

/// Service for managing active orders with local storage persistence
class ActiveOrdersService {
  static const String _keyPrefix = 'active_orders_';
  static const String _keyMerchant = 'active_orders_merchant';
  static const String _keyBranch = 'active_orders_branch';

  final SharedPreferences _prefs;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ActiveOrdersService({
    required SharedPreferences prefs,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _prefs = prefs,
       _firestore = firestore,
       _auth = auth;

  /// Get storage key for current user
  String get _userKey {
    final uid = _auth.currentUser?.uid ?? 'anonymous';
    return '$_keyPrefix$uid';
  }

  /// Get stored merchant ID
  String? getStoredMerchantId() => _prefs.getString(_keyMerchant);

  /// Get stored branch ID
  String? getStoredBranchId() => _prefs.getString(_keyBranch);

  /// Store merchant/branch context
  Future<void> setContext(String merchantId, String branchId) async {
    await _prefs.setString(_keyMerchant, merchantId);
    await _prefs.setString(_keyBranch, branchId);
  }

  /// Get list of active order IDs from local storage
  List<String> getStoredOrderIds() {
    return _prefs.getStringList(_userKey) ?? [];
  }

  /// Add order ID to local storage
  Future<void> addOrderId(String orderId) async {
    final current = getStoredOrderIds();
    if (!current.contains(orderId)) {
      current.add(orderId);
      await _prefs.setStringList(_userKey, current);
    }
  }

  /// Remove order ID from local storage
  Future<void> removeOrderId(String orderId) async {
    final current = getStoredOrderIds();
    current.remove(orderId);
    await _prefs.setStringList(_userKey, current);
  }

  /// Clear all stored order IDs
  Future<void> clearOrderIds() async {
    await _prefs.remove(_userKey);
  }

  om.OrderStatus _statusFromFirestore(String s) {
    switch (s) {
      case 'pending':
        return om.OrderStatus.pending;
      case 'accepted':
        return om.OrderStatus.accepted;
      case 'preparing':
        return om.OrderStatus.preparing;
      case 'ready':
        return om.OrderStatus.ready;
      case 'served':
        return om.OrderStatus.served;
      case 'cancelled':
        return om.OrderStatus.cancelled;
      default:
        return om.OrderStatus.pending;
    }
  }

  DateTime? _tsToDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  BahrainAddress? _addressFromAny(dynamic v) {
    if (v == null) return null;
    if (v is BahrainAddress) return v;
    if (v is Map<String, dynamic>) return BahrainAddress.fromMap(v);
    if (v is Map) return BahrainAddress.fromMap(Map<String, dynamic>.from(v));
    return null;
  }

  /// Watch active orders from Firestore
  /// Only returns orders that are in active states (pending, accepted, preparing, ready)
  Stream<List<om.Order>> watchActiveOrders(String merchantId, String branchId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(branchId)
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'accepted', 'preparing', 'ready'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map<om.Order>((doc) {
            final data = doc.data();

            // Parse fulfillment type with backward compatibility
            om.FulfillmentType fulfillmentType;
            final fulfillmentTypeStr = data['fulfillmentType'] as String?;
            if (fulfillmentTypeStr != null && fulfillmentTypeStr.isNotEmpty) {
              fulfillmentType = om.FulfillmentTypeX.fromFirestore(
                fulfillmentTypeStr,
              );
            } else {
              final address = data['customerAddress'];
              final carPlate = data['customerCarPlate'] as String?;
              if (address != null) {
                fulfillmentType = om.FulfillmentType.delivery;
              } else if (carPlate != null) {
                fulfillmentType = om.FulfillmentType.carPickup;
              } else {
                fulfillmentType = om.FulfillmentType.dineIn;
              }
            }

            // Parse order items
            final itemsList = (data['items'] as List?) ?? const <dynamic>[];
            final items = itemsList.map<om.OrderItem>((item) {
              final itemMap = Map<String, dynamic>.from(item as Map);
              return om.OrderItem(
                productId: (itemMap['productId'] ?? '').toString(),
                name: (itemMap['name'] ?? '').toString(),
                price: (itemMap['price'] as num?)?.toDouble() ?? 0.0,
                qty: (itemMap['qty'] as int?) ?? 1,
                note: itemMap['note'] as String?,
              );
            }).toList();

            final createdAt = _tsToDate(data['createdAt']) ?? DateTime.now();

            return om.Order(
              orderId: doc.id,
              orderNo: (data['orderNo'] ?? '').toString(),
              status: _statusFromFirestore(
                (data['status'] ?? 'pending').toString(),
              ),
              items: items,
              subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
              createdAt: createdAt,
              fulfillmentType: fulfillmentType,
              table: data['table'] as String?,
              customerPhone: data['customerPhone'] as String?,
              customerCarPlate: data['customerCarPlate'] as String?,
              customerAddress: _addressFromAny(data['customerAddress']),
              loyaltyDiscount: (data['loyaltyDiscount'] as num?)?.toDouble(),
              loyaltyPointsUsed: data['loyaltyPointsUsed'] as int?,
              cancellationReason: data['cancellationReason'] as String?,
            );
          }).toList();
        });
  }

  /// Sync local storage with current active orders
  /// Call this after fetching orders to clean up outdated IDs
  Future<void> syncWithFirestore(List<om.Order> activeOrders) async {
    final activeIds = activeOrders.map((o) => o.orderId).toList();
    await _prefs.setStringList(_userKey, activeIds);
  }
}

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

/// Provider for ActiveOrdersService
final activeOrdersServiceProvider = Provider<ActiveOrdersService?>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);

  return prefsAsync.when(
    data: (prefs) => ActiveOrdersService(
      prefs: prefs,
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
    ),
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});

/// Provider that watches active orders from Firestore
/// Returns list of orders in active states (pending, accepted, preparing, ready)
/// Syncs with local storage for persistence across refreshes
final activeOrdersStreamProvider = StreamProvider<List<om.Order>>((ref) {
  final ids = ref.watch(effectiveIdsProvider);
  final service = ref.watch(activeOrdersServiceProvider);

  debugPrint(
    '[ActiveOrders] Provider called - ids: $ids, service: ${service != null}',
  );

  if (ids == null || service == null) {
    debugPrint(
      '[ActiveOrders] Returning empty stream - missing ids or service',
    );
    return Stream.value([]);
  }

  service.setContext(ids.merchantId, ids.branchId);
  debugPrint(
    '[ActiveOrders] Watching orders for merchant=${ids.merchantId} branch=${ids.branchId}',
  );

  return service.watchActiveOrders(ids.merchantId, ids.branchId).map((orders) {
    debugPrint('[ActiveOrders] Received ${orders.length} active orders');
    service.syncWithFirestore(orders);
    return orders;
  });
});

/// Provider for active orders count (for badge display)
final activeOrdersCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(activeOrdersStreamProvider);
  final service = ref.watch(activeOrdersServiceProvider);
  
  // Show persisted count immediately while stream loads
  final persistedCount = service?.getStoredOrderIds().length ?? 0;
  
  final streamCount = ordersAsync.maybeWhen(
    data: (orders) {
      debugPrint('[ActiveOrdersCount] Stream has ${orders.length} orders');
      return orders.length;
    },
    orElse: () => persistedCount,
  );
  
  debugPrint('[ActiveOrdersCount] Returning count: $streamCount (persisted: $persistedCount)');
  return streamCount;
});
