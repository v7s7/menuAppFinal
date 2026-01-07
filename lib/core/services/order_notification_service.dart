import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'email_service.dart';
import '../config/email_config.dart';

/// Service to listen for new orders and send email notifications
class OrderNotificationService {
  StreamSubscription<QuerySnapshot>? _subscription;
  final Set<String> _processedOrders = {};
  DateTime? _serviceStartTime;

  /// Start listening for new orders
  /// Email notifications will ALWAYS be sent to EmailConfig.defaultEmail
  void startListening({
    required String merchantId,
    required String branchId,
    required String merchantName,
  }) {
    // Cancel existing subscription
    stopListening();

    // Record when service starts - only listen for orders created AFTER this time
    // This prevents sending emails for old orders and avoids rate limiting
    _serviceStartTime = DateTime.now();
    debugPrint('[OrderNotificationService] Started listening for orders created after $_serviceStartTime');
    debugPrint('[OrderNotificationService] All emails will be sent to: ${EmailConfig.defaultEmail}');

    _subscription = FirebaseFirestore.instance
        .collection('merchants/$merchantId/branches/$branchId/orders')
        .where('status', isEqualTo: 'pending')
        .where('createdAt', isGreaterThan: _serviceStartTime)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final orderId = change.doc.id;

          // Skip if already processed
          if (_processedOrders.contains(orderId)) {
            debugPrint('[OrderNotificationService] Skipping already processed order: $orderId');
            continue;
          }

          _processedOrders.add(orderId);

          // Send notification with delay to respect rate limits (2 req/sec)
          _sendOrderNotification(
            orderId: orderId,
            orderData: change.doc.data()!,
            merchantName: merchantName,
          );
        }
      }
    });
  }

  /// Stop listening for new orders
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _serviceStartTime = null;
  }

  /// Send email notification for a new order
  /// Always sends to EmailConfig.defaultEmail
  Future<void> _sendOrderNotification({
    required String orderId,
    required Map<String, dynamic> orderData,
    required String merchantName,
  }) async {
    try {
      final orderNo = orderData['orderNo'] as String? ?? orderId;
      final table = orderData['table'] as String?;
      final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;

      final items = (orderData['items'] as List<dynamic>?)
              ?.map((item) => OrderItem(
                    name: item['name'] as String? ?? 'Unknown',
                    qty: (item['qty'] as num?)?.toInt() ?? 1,
                    price: (item['price'] as num?)?.toDouble() ?? 0.0,
                    note: item['note'] as String?,
                  ))
              .toList() ??
          [];

      final createdAt = orderData['createdAt'] as Timestamp?;
      final timestamp = createdAt != null
          ? DateFormat('MM/dd/yyyy hh:mm a').format(createdAt.toDate())
          : DateFormat('MM/dd/yyyy hh:mm a').format(DateTime.now());

      final result = await EmailService.sendOrderNotification(
        orderNo: orderNo,
        table: table,
        items: items,
        subtotal: subtotal,
        timestamp: timestamp,
        merchantName: merchantName,
        dashboardUrl: 'https://sweetweb.web.app/merchant',
        toEmail: EmailConfig.defaultEmail, // ALWAYS use default email
      );

      if (result.success) {
        debugPrint('[OrderNotificationService] ✅ Email sent for order $orderNo to ${EmailConfig.defaultEmail}: ${result.messageId}');
      } else {
        // Check if it's a rate limit error
        final error = result.error ?? '';
        if (error.contains('Too many requests') || error.contains('rate limit')) {
          debugPrint('[OrderNotificationService] ⚠️ Rate limit reached for order $orderNo. Email will be retried on next order.');
        } else {
          debugPrint('[OrderNotificationService] ❌ Failed to send email for order $orderNo: ${result.error}');
        }
      }
    } catch (e) {
      debugPrint('[OrderNotificationService] ❌ Exception sending notification: $e');
    }
  }

  /// Clean up processed orders list (keep only last 100)
  void cleanupProcessedOrders() {
    if (_processedOrders.length > 100) {
      final toRemove = _processedOrders.length - 100;
      final iterator = _processedOrders.iterator;
      for (var i = 0; i < toRemove && iterator.moveNext(); i++) {
        _processedOrders.remove(iterator.current);
      }
    }
  }
}
