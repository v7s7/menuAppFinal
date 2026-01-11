import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Avoid name clash with Firestore's internal Order types.
import 'order_models.dart' as om;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/slug_routing.dart';
import '../../../core/models/bahrain_address.dart';

typedef Json = Map<String, dynamic>;

/// OrderService (FREE plan):
/// - createOrder(): writes directly to Firestore (no Cloud Functions).
/// - watchOrder(): streams the order doc from Firestore.
class OrderService {
  OrderService({required this.merchantId, required this.branchId});

  final String merchantId;
  final String branchId;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // Shorthands
  String get _m => merchantId;
  String get _b => branchId;

  /// Creates an order by writing to Firestore (server-authoritative rules).
  ///
  /// Firestore Rules will validate:
  /// - userId matches current uid
  /// - status == "pending"
  /// - merchantId / branchId match path
  /// - items is a non-empty list (bounded)
  /// - Only staff can later update `status`
  ///
  /// Validates fulfillment requirements:
  /// - carPickup requires customerCarPlate
  /// - delivery requires customerAddress
  /// - dineIn requires table
  Future<om.Order> createOrder({
    required List<om.OrderItem> items,
    required om.FulfillmentType fulfillmentType,
    String? table,
    String? customerPhone,
    String? customerCarPlate,
    double? loyaltyDiscount,
    int? loyaltyPointsUsed,
    Map<String, dynamic>? customerAddress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final isAnon = user?.isAnonymous ?? true;
    if (uid == null) {
      throw StateError('Not signed in; initialize anonymous auth first.');
    }
    if (items.isEmpty) {
      throw StateError('Cart is empty.');
    }

    // Validate fulfillment requirements
    switch (fulfillmentType) {
      case om.FulfillmentType.carPickup:
        if (customerCarPlate == null || customerCarPlate.trim().isEmpty) {
          throw StateError('Car plate is required for car pickup orders.');
        }
        break;
      case om.FulfillmentType.delivery:
        if (customerAddress == null || customerAddress.isEmpty) {
          throw StateError('Delivery address is required for delivery orders.');
        }
        // Validate required address fields
        if (customerAddress['home'] == null ||
            customerAddress['road'] == null ||
            customerAddress['block'] == null ||
            customerAddress['city'] == null) {
          throw StateError('Complete address (Home, Road, Block, City) is required for delivery.');
        }
        break;
      case om.FulfillmentType.dineIn:
        if (table == null || table.trim().isEmpty) {
          throw StateError('Table number is required for dine-in orders.');
        }
        break;
    }

    // Subtotal rounded to 3 decimals (BHD)
    final subtotal = double.parse(
      items
          .fold<num>(0, (s, it) => s + (it.price * it.qty))
          .toStringAsFixed(3),
    );

    try {
      if (kDebugMode) {
        debugPrint(
          '[OrderService] Creating order m=$_m b=$_b items=${items.length}',
        );
      }

      final doc = _fs
          .collection('merchants')
          .doc(_m)
          .collection('branches')
          .doc(_b)
          .collection('orders')
          .doc();

      // Get next order number using transaction
      final counterDoc = _fs
          .collection('merchants')
          .doc(_m)
          .collection('branches')
          .doc(_b)
          .collection('counters')
          .doc('orders');

      final String orderNo = await _fs.runTransaction<String>((transaction) async {
        final counterSnap = await transaction.get(counterDoc);
        final currentCount = counterSnap.exists ? (counterSnap.data()?['count'] ?? 0) : 0;
        final nextCount = currentCount + 1;

        // Update counter
        transaction.set(counterDoc, {'count': nextCount}, SetOptions(merge: true));

        // Format as ORD-001, ORD-002, etc.
        return 'ORD-${nextCount.toString().padLeft(3, '0')}';
      });

      final customerUid = (!isAnon) ? user!.uid : null;
      await doc.set({
        'merchantId': _m,
        'branchId': _b,
        'userId': uid,
        if (customerUid != null) 'customerUid': customerUid,
        if (!isAnon && customerPhone != null && customerPhone.isNotEmpty)
          'customerPhoneE164': customerPhone,
        'status': 'pending',
        'fulfillmentType': fulfillmentType.toFirestore(), // NEW: Canonical fulfillment type
        'items': items.map((e) => {
              'productId': e.productId,
              'name': e.name,
              'price': e.price,
              'qty': e.qty,
              if ((e.note ?? '').trim().isNotEmpty) 'note': e.note!.trim(),
            }).toList(),
        'subtotal': subtotal,
        'currency': 'BHD',
        'table': table,
        'createdAt': FieldValue.serverTimestamp(),
        'orderNo': orderNo, // Add generated order number
        // Loyalty fields (optional)
        if (customerPhone != null) 'customerPhone': customerPhone,
        if (customerCarPlate != null) 'customerCarPlate': customerCarPlate,
        if (loyaltyDiscount != null) 'loyaltyDiscount': loyaltyDiscount,
        if (loyaltyPointsUsed != null) 'loyaltyPointsUsed': loyaltyPointsUsed,
        // NEW: Additional checkout fields (optional)
        if (customerAddress != null) 'customerAddress': customerAddress,
        // WhatsApp notification tracking flags
        'notifications': {
          'waNewSent': false,
          'waCancelSent': false,
        },
      });

    return om.Order(
      orderId: doc.id,
      orderNo: orderNo,
      status: om.OrderStatus.pending,
      createdAt: DateTime.now(),
      items: items,
      subtotal: subtotal,
      fulfillmentType: fulfillmentType,
      customerUid: customerUid,
      customerPhoneE164: (!isAnon) ? customerPhone : null,
      table: table,
      customerPhone: customerPhone,
      customerCarPlate: customerCarPlate,
      loyaltyDiscount: loyaltyDiscount,
      loyaltyPointsUsed: loyaltyPointsUsed,
      customerAddress: customerAddress != null ? BahrainAddress.fromMap(customerAddress) : null,
    );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('createOrder(): Unexpected error: $e\n$st');
      }
      rethrow;
    }
  }

  /// Live stream of the order document.
  Stream<om.Order> watchOrder(String orderId) {
    final docRef = _orderDoc(orderId);
    return docRef.snapshots().where((s) => s.exists).map(_orderFromSnapshot);
  }

  /// Stream of recent orders for the logged-in customer (scoped to merchant/branch).
  Stream<List<om.Order>> watchCustomerOrders(String customerUid,
      {int limit = 50}) {
    final q = _fs
        .collection('merchants')
        .doc(_m)
        .collection('branches')
        .doc(_b)
        .collection('orders')
        .where('customerUid', isEqualTo: customerUid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return q.snapshots().map(
          (qs) => qs.docs
              .map(_orderFromSnapshot)
              .toList(),
        );
  }

  DocumentReference<Map<String, dynamic>> _orderDoc(String orderId) {
    return _fs
        .collection('merchants')
        .doc(_m)
        .collection('branches')
        .doc(_b)
        .collection('orders')
        .doc(orderId);
  }

  om.OrderStatus _statusFromString(String s) {
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

  om.OrderItem _itemFromMap(Json m) {
    return om.OrderItem(
      productId: _asString(m['productId']),
      name: _asString(m['name']),
      price: _asNum(m['price']).toDouble(),
      qty: _asNum(m['qty']).toInt(),
      note: _asNullableString(m['note']), // NEW
    );
  }

  // --------------------------- helpers: parsing ---------------------------

  static Json _safeJson(Object? o) {
    if (o is Map<String, dynamic>) return o;
    if (o is Map) return Map<String, dynamic>.from(o);
    throw StateError('Expected Map, got $o');
  }

  static String _asString(Object? v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static String? _asNullableString(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static num _asNum(Object? v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) {
      final parsed = num.tryParse(v);
      return parsed ?? fallback;
    }
    return fallback;
  }

  om.Order _orderFromSnapshot(DocumentSnapshot<Json> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    final String statusStr = _asString(data['status'], fallback: 'pending');

    final dynamic ts = data['createdAt'];
    final DateTime createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();

    final List<dynamic> rawItems = (data['items'] as List?) ?? const [];
    final List<om.OrderItem> itemsList = rawItems
        .whereType<Map>()
        .map((m) => _itemFromMap(_safeJson(m)))
        .toList();

    final double subtotalNum = (data['subtotal'] is num)
        ? (data['subtotal'] as num).toDouble()
        : itemsList.fold<double>(
            0.0, (s, it) => s + (it.price * it.qty.toDouble()));

    BahrainAddress? address;
    if (data['customerAddress'] != null && data['customerAddress'] is Map) {
      try {
        address = BahrainAddress.fromMap(_safeJson(data['customerAddress']));
      } catch (_) {
        address = null;
      }
    }

    om.FulfillmentType fulfillmentType;
    final fulfillmentTypeStr = _asNullableString(data['fulfillmentType']);

    if (fulfillmentTypeStr != null && fulfillmentTypeStr.isNotEmpty) {
      fulfillmentType = om.FulfillmentTypeX.fromFirestore(fulfillmentTypeStr);
    } else {
      if (address != null) {
        fulfillmentType = om.FulfillmentType.delivery;
      } else if (_asNullableString(data['customerCarPlate']) != null &&
          _asNullableString(data['customerCarPlate'])!.trim().isNotEmpty) {
        fulfillmentType = om.FulfillmentType.carPickup;
      } else {
        fulfillmentType = _asNullableString(data['table']) != null &&
                _asNullableString(data['table'])!.trim().isNotEmpty
            ? om.FulfillmentType.dineIn
            : om.FulfillmentType.carPickup;
      }
    }

    return om.Order(
      orderId: snap.id,
      orderNo: _asString(data['orderNo'], fallback: '—'),
      status: _statusFromString(statusStr),
      createdAt: createdAt,
      items: itemsList,
      subtotal: double.parse(subtotalNum.toStringAsFixed(3)),
      fulfillmentType: fulfillmentType,
      table: _asNullableString(data['table']),
      customerPhone: _asNullableString(data['customerPhone']),
      customerCarPlate: _asNullableString(data['customerCarPlate']),
      loyaltyDiscount: data['loyaltyDiscount'] != null
          ? _asNum(data['loyaltyDiscount']).toDouble()
          : null,
      loyaltyPointsUsed: data['loyaltyPointsUsed'] != null
          ? _asNum(data['loyaltyPointsUsed']).toInt()
          : null,
      customerAddress: address,
      cancellationReason: _asNullableString(data['cancellationReason']),
      customerUid: _asNullableString(data['customerUid']),
      customerPhoneE164: _asNullableString(data['customerPhoneE164']),
    );
  }
}

/// Riverpod provider resolving pretty links (slug) or explicit IDs.
final orderServiceProvider = Provider<OrderService>((ref) {
  final ids = ref.watch(effectiveIdsProvider);
  if (ids == null) {
    throw StateError('Missing merchant/branch (provide ?m=&b= or a valid slug).');
  }
  return OrderService(merchantId: ids.merchantId, branchId: ids.branchId);
});
