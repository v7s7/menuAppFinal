import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'order_models.dart' as om;
import '../../../core/config/slug_routing.dart' show effectiveIdsProvider;

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
  })  : _prefs = prefs,
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
      return snapshot.docs.map((doc) {
        final data = doc.data();

        // Parse fulfillment type with backward compatibility
        om.FulfillmentType fulfillmentType;
        final fulfillmentTypeStr = data['fulfillmentType'] as String?;
        if (fulfillmentTypeStr != null && fulfillmentTypeStr.isNotEmpty) {
          fulfillmentType = om.FulfillmentTypeX.fromFirestore(fulfillmentTypeStr);
        } else {
          // Infer from existing fields for old orders
          final address = data['customerAddress'] as Map<String, dynamic>?;
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
        final itemsList = data['items'] as List<dynamic>;
        final items = itemsList.map((item) {
          final itemMap = item as Map<String, dynamic>;
          return om.OrderItem(
            productId: itemMap['productId'] as String,
            name: itemMap['name'] as String,
            price: (itemMap['price'] as num).toDouble(),
            qty: itemMap['qty'] as int,
            note: itemMap['note'] as String?,
          );
        }).toList();

        return om.Order(
          orderId: doc.id,
          orderNo: data['orderNo'] as String,
          userId: data['userId'] as String,
          merchantId: data['merchantId'] as String,
          branchId: data['branchId'] as String,
          status: om.OrderStatusX.fromFirestore(data['status'] as String),
          items: items,
          subtotal: (data['subtotal'] as num).toDouble(),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          updatedAt: data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : (data['createdAt'] as Timestamp).toDate(),
          fulfillmentType: fulfillmentType,
          table: data['table'] as String?,
          customerPhone: data['customerPhone'] as String?,
          customerCarPlate: data['customerCarPlate'] as String?,
          customerAddress: data['customerAddress'] as Map<String, dynamic>?,
          loyaltyDiscount: data['loyaltyDiscount'] != null
              ? (data['loyaltyDiscount'] as num).toDouble()
              : null,
          loyaltyPointsUsed: data['loyaltyPointsUsed'] as int?,
          acceptedAt: data['acceptedAt'] != null
              ? (data['acceptedAt'] as Timestamp).toDate()
              : null,
          preparingAt: data['preparingAt'] != null
              ? (data['preparingAt'] as Timestamp).toDate()
              : null,
          readyAt: data['readyAt'] != null
              ? (data['readyAt'] as Timestamp).toDate()
              : null,
          servedAt: data['servedAt'] != null
              ? (data['servedAt'] as Timestamp).toDate()
              : null,
          cancelledAt: data['cancelledAt'] != null
              ? (data['cancelledAt'] as Timestamp).toDate()
              : null,
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
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
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
    error: (_, __) => null,
  );
});

/// Provider that watches active orders from Firestore
/// Returns list of orders in active states (pending, accepted, preparing, ready)
/// Syncs with local storage for persistence across refreshes
final activeOrdersStreamProvider = StreamProvider<List<om.Order>>((ref) {
  // Import effectiveIdsProvider from slug_routing.dart
  // We'll add the import at the top of the file
  final ids = ref.watch(effectiveIdsProvider);
  final service = ref.watch(activeOrdersServiceProvider);

  // If IDs not available or service not ready, return empty stream
  if (ids == null || service == null) {
    return Stream.value([]);
  }

  // Store context for this session
  service.setContext(ids.merchantId, ids.branchId);

  // Watch active orders and sync with local storage
  return service.watchActiveOrders(ids.merchantId, ids.branchId).map((orders) {
    // Sync local storage with current active orders
    service.syncWithFirestore(orders);
    return orders;
  });
});

/// Provider for active orders count (for badge display)
final activeOrdersCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(activeOrdersStreamProvider);
  return ordersAsync.maybeWhen(
    data: (orders) => orders.length,
    orElse: () => 0,
  );
});
