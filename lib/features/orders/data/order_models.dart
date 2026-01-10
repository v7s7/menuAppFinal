import 'package:flutter/foundation.dart';
import '../../loyalty/data/checkout_fields_config.dart';

enum OrderStatus { pending, accepted, preparing, ready, served, cancelled }

enum FulfillmentType { carPickup, delivery, dineIn }

extension FulfillmentTypeX on FulfillmentType {
  String get label {
    switch (this) {
      case FulfillmentType.carPickup:
        return 'Car Pickup';
      case FulfillmentType.delivery:
        return 'Delivery';
      case FulfillmentType.dineIn:
        return 'Dine-in';
    }
  }

  String toFirestore() {
    switch (this) {
      case FulfillmentType.carPickup:
        return 'car_pickup';
      case FulfillmentType.delivery:
        return 'delivery';
      case FulfillmentType.dineIn:
        return 'dine_in';
    }
  }

  static FulfillmentType fromFirestore(String value) {
    switch (value) {
      case 'car_pickup':
        return FulfillmentType.carPickup;
      case 'delivery':
        return FulfillmentType.delivery;
      case 'dine_in':
        return FulfillmentType.dineIn;
      default:
        return FulfillmentType.carPickup; // Default fallback
    }
  }
}

extension OrderStatusX on OrderStatus {
  String get label => describeEnum(this).toUpperCase();
}

class OrderItem {
  final String productId;
  final String name;
  final double price; // unit price
  final int qty;
  final String? note; // NEW: per-item note

  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.note,
  });

  double get lineTotal => price * qty;
}

class Order {
  final String orderId;   // e.g., local_1700000000000
  final String orderNo;   // human readable, e.g., "A-001" (stubbed)
  final OrderStatus status;
  final DateTime createdAt;
  final List<OrderItem> items;
  final double subtotal;

  // Fulfillment type (REQUIRED - canonical source of truth)
  final FulfillmentType fulfillmentType;

  final String? table; // Table number: from QR scan or manual entry at checkout

  // Loyalty fields
  final String? customerPhone; // Customer phone number for loyalty
  final String? customerCarPlate; // Customer car plate
  final double? loyaltyDiscount; // Discount from redeemed points
  final int? loyaltyPointsUsed; // Points redeemed for this order

  // NEW: Additional checkout fields
  final BahrainAddress? customerAddress; // Home address for delivery

  // Cancellation
  final String? cancellationReason; // Reason for cancellation (optional)

  const Order({
    required this.orderId,
    required this.orderNo,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.subtotal,
    required this.fulfillmentType,
    this.table,
    this.customerPhone,
    this.customerCarPlate,
    this.loyaltyDiscount,
    this.loyaltyPointsUsed,
    this.customerAddress,
    this.cancellationReason,
  });

  Order copyWith({OrderStatus? status, String? cancellationReason}) {
    return Order(
      orderId: orderId,
      orderNo: orderNo,
      status: status ?? this.status,
      createdAt: createdAt,
      items: items,
      subtotal: subtotal,
      fulfillmentType: fulfillmentType,
      table: table,
      customerPhone: customerPhone,
      customerCarPlate: customerCarPlate,
      loyaltyDiscount: loyaltyDiscount,
      loyaltyPointsUsed: loyaltyPointsUsed,
      customerAddress: customerAddress,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}
  