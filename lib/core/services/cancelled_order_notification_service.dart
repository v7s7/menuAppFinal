import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'email_service.dart';
import '../config/email_config.dart';

/// Service to listen for cancelled orders and send email notifications
class CancelledOrderNotificationService {
  StreamSubscription<QuerySnapshot>? _subscription;
  final Set<String> _processedOrders = {};
  DateTime? _serviceStartTime;

  /// Start listening for cancelled orders
  /// Email notifications will be sent to EmailConfig.defaultEmail
  void startListening({
    required String merchantId,
    required String branchId,
    required String merchantName,
  }) {
    // Cancel existing subscription
    stopListening();

    // Record when service starts - only listen for orders cancelled AFTER this time
    // This prevents sending emails for old cancelled orders
    _serviceStartTime = DateTime.now();
    debugPrint('[CancelledOrderNotificationService] Started listening for cancelled orders after $_serviceStartTime');
    debugPrint('[CancelledOrderNotificationService] All emails will be sent to: ${EmailConfig.defaultEmail}');

    _subscription = FirebaseFirestore.instance
        .collection('merchants/$merchantId/branches/$branchId/orders')
        .where('status', isEqualTo: 'cancelled')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final orderId = change.doc.id;
          final orderData = change.doc.data()!;

          // Skip if already processed
          if (_processedOrders.contains(orderId)) {
            debugPrint('[CancelledOrderNotificationService] Skipping already processed order: $orderId');
            continue;
          }

          // Only process orders cancelled AFTER service started
          final cancelledAt = orderData['cancelledAt'] as Timestamp?;
          if (cancelledAt == null || cancelledAt.toDate().isBefore(_serviceStartTime!)) {
            debugPrint('[CancelledOrderNotificationService] Skipping old cancelled order: $orderId');
            continue;
          }

          _processedOrders.add(orderId);

          // Send cancellation notification
          _sendCancellationNotification(
            orderId: orderId,
            orderData: orderData,
            merchantName: merchantName,
          );
        }
      }
    });
  }

  /// Stop listening for cancelled orders
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _serviceStartTime = null;
  }

  /// Send email notification for a cancelled order
  /// Always sends to EmailConfig.defaultEmail
  Future<void> _sendCancellationNotification({
    required String orderId,
    required Map<String, dynamic> orderData,
    required String merchantName,
  }) async {
    try {
      final orderNo = orderData['orderNo'] as String? ?? orderId;
      final table = orderData['table'] as String?;
      final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
      final cancellationReason = orderData['cancellationReason'] as String?;

      final items = (orderData['items'] as List<dynamic>?)
              ?.map((item) => OrderItem(
                    name: item['name'] as String? ?? 'Unknown',
                    qty: (item['qty'] as num?)?.toInt() ?? 1,
                    price: (item['price'] as num?)?.toDouble() ?? 0.0,
                    note: item['note'] as String?,
                  ))
              .toList() ??
          [];

      final cancelledAt = orderData['cancelledAt'] as Timestamp?;
      final timestamp = cancelledAt != null
          ? DateFormat('MM/dd/yyyy hh:mm a').format(cancelledAt.toDate())
          : DateFormat('MM/dd/yyyy hh:mm a').format(DateTime.now());

      final result = await EmailService.sendOrderCancellation(
        orderNo: orderNo,
        table: table,
        items: items,
        subtotal: subtotal,
        timestamp: timestamp,
        merchantName: merchantName,
        dashboardUrl: 'https://sweetweb.web.app/merchant',
        toEmail: EmailConfig.defaultEmail, // ALWAYS use default email
        cancellationReason: cancellationReason,
      );

      if (result.success) {
        debugPrint('[CancelledOrderNotificationService] ✅ Cancellation email sent for order $orderNo to ${EmailConfig.defaultEmail}: ${result.messageId}');
      } else {
        debugPrint('[CancelledOrderNotificationService] ❌ Failed to send cancellation email for order $orderNo: ${result.error}');
      }
    } catch (e) {
      debugPrint('[CancelledOrderNotificationService] ❌ Exception sending cancellation notification: $e');
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
