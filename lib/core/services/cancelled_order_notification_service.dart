import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'email_service.dart';

/// Service to listen for cancelled orders and send email notifications
/// Emails are sent ONLY to the merchant's configured email address
class CancelledOrderNotificationService {
  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  StreamSubscription<DocumentSnapshot>? _settingsSubscription;
  final Set<String> _processedOrders = {};
  DateTime? _serviceStartTime;

  // Merchant-specific email configuration
  String? _merchantEmail;
  bool _emailEnabled = false;
  String? _merchantId;
  String? _branchId;
  String? _merchantName;

  /// Start listening for cancelled orders
  Future<void> startListening({
    required String merchantId,
    required String branchId,
    required String merchantName,
  }) async {
    stopListening();

    _merchantId = merchantId;
    _branchId = branchId;
    _merchantName = merchantName;
    _serviceStartTime = DateTime.now();

    print('[CancelledOrderNotificationService] Starting for merchant: $merchantId, branch: $branchId');

    final settingsValid = await _loadEmailSettings();
    if (!settingsValid) {
      print('[CancelledOrderNotificationService] ⚠️ Email notifications NOT started');
      return;
    }

    print('[CancelledOrderNotificationService] ✅ Email notifications enabled, sending to: $_merchantEmail');

    _startSettingsListener();

    // Listen to cancelled orders
    // NO time filtering - old orders can be cancelled later
    // Idempotency via transaction prevents duplicate emails for historical cancellations
    _ordersSubscription = FirebaseFirestore.instance
        .collection('merchants/$merchantId/branches/$branchId/orders')
        .where('status', isEqualTo: 'cancelled')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final orderId = change.doc.id;

          // Do NOT check _processedOrders here - allow retries

          _sendCancellationNotification(orderId: orderId, orderData: change.doc.data()!);
        }
      }
    });
  }

  Future<bool> _loadEmailSettings() async {
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .doc('merchants/$_merchantId/branches/$_branchId/config/settings')
          .get();

      if (!settingsDoc.exists) return false;

      final emailData = settingsDoc.data()?['emailNotifications'] as Map<String, dynamic>?;
      if (emailData == null) return false;

      _emailEnabled = emailData['enabled'] as bool? ?? false;
      final email = emailData['email'] as String?;

      if (!_emailEnabled || email == null || email.trim().isEmpty) return false;
      if (!_isValidEmail(email.trim())) return false;

      _merchantEmail = email.trim();
      return true;
    } catch (e) {
      print('[CancelledOrderNotificationService] ❌ Failed to load settings: $e');
      return false;
    }
  }

  void _startSettingsListener() {
    _settingsSubscription = FirebaseFirestore.instance
        .doc('merchants/$_merchantId/branches/$_branchId/config/settings')
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final emailData = snapshot.data()?['emailNotifications'] as Map<String, dynamic>?;
      if (emailData == null) return;

      final enabled = emailData['enabled'] as bool? ?? false;
      final email = emailData['email'] as String?;

      if (enabled && email != null && email.trim().isNotEmpty && _isValidEmail(email.trim())) {
        final newEmail = email.trim();
        if (newEmail != _merchantEmail) {
          print('[CancelledOrderNotificationService] 🔄 Email updated: $_merchantEmail → $newEmail');
          _merchantEmail = newEmail;
          _emailEnabled = true;
        }
      } else if (!enabled && _emailEnabled) {
        _emailEnabled = false;
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email);
  }

  /// Send cancellation email with two-phase idempotency, lock TTL, and failure cooldown
  Future<void> _sendCancellationNotification({
    required String orderId,
    required Map<String, dynamic> orderData,
  }) async {
    if (!_emailEnabled || _merchantEmail == null) {
      return;
    }

    // Skip if already successfully sent in this session
    if (_processedOrders.contains(orderId)) {
      return;
    }

    final orderRef = FirebaseFirestore.instance
        .doc('merchants/$_merchantId/branches/$_branchId/orders/$orderId');

    try {
      // PHASE 1: Transaction with lock TTL (10 min) and failure cooldown (2 min)
      final shouldSend = await FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
        final freshDoc = await transaction.get(orderRef);
        if (!freshDoc.exists) return false;

        final notifications = freshDoc.data()?['notifications'] as Map<String, dynamic>?;

        // Already sent? Skip
        if (notifications?['cancelledEmailSentAt'] != null) {
          return false;
        }

        // FAILURE COOLDOWN: Prevent rapid retries after failure
        final failedAt = notifications?['cancelledEmailFailedAt'] as Timestamp?;
        if (failedAt != null) {
          final timeSinceFailure = DateTime.now().difference(failedAt.toDate());
          if (timeSinceFailure.inSeconds < 120) {
            // Wait 2 minutes before retry
            return false;
          }
        }

        // LOCK TTL: Check reservation with 10-minute timeout
        final reservedAt = notifications?['cancelledEmailReservedAt'] as Timestamp?;
        if (reservedAt != null) {
          final age = DateTime.now().difference(reservedAt.toDate());
          if (age.inMinutes < 10) {
            // Fresh lock - skip
            return false;
          }
          // Stale lock - re-reserve
          print('[CancelledOrderNotificationService] ⚠️ Stale lock detected (${age.inMinutes} min old), re-reserving');
        }

        // Reserve
        transaction.set(
          orderRef,
          {
            'notifications': {
              'cancelledEmailReservedAt': FieldValue.serverTimestamp(),
            },
          },
          SetOptions(merge: true),
        );

        return true;
      });

      if (!shouldSend) {
        return;
      }

      // RE-CHECK: Email may have been disabled after reservation
      if (!_emailEnabled || _merchantEmail == null) {
        print('[CancelledOrderNotificationService] ⚠️ Email disabled after reservation, clearing lock');
        await orderRef.set({
          'notifications': {
            'cancelledEmailReservedAt': FieldValue.delete(),
          },
        }, SetOptions(merge: true));
        return;
      }

      // PHASE 2: Send email
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

      final updatedAt = orderData['updatedAt'] as Timestamp?;
      final createdAt = orderData['createdAt'] as Timestamp?;
      final timestamp = updatedAt != null
          ? DateFormat('MM/dd/yyyy hh:mm a').format(updatedAt.toDate())
          : (createdAt != null
              ? DateFormat('MM/dd/yyyy hh:mm a').format(createdAt.toDate())
              : DateFormat('MM/dd/yyyy hh:mm a').format(DateTime.now()));

      final result = await EmailService.sendOrderCancellation(
        orderNo: orderNo,
        table: table,
        items: items,
        subtotal: subtotal,
        timestamp: timestamp,
        merchantName: _merchantName ?? 'Your Store',
        dashboardUrl: 'https://sweetweb.web.app/merchant',
        toEmail: _merchantEmail!,
        cancellationReason: cancellationReason,
      );

      if (result.success) {
        print('[CancelledOrderNotificationService] ✅ Email sent for $orderNo to $_merchantEmail: ${result.messageId}');

        // PHASE 3a: Success - mark as sent, clear lock and errors
        await orderRef.set({
          'notifications': {
            'cancelledEmailSentAt': FieldValue.serverTimestamp(),
            'cancelledEmailMessageId': result.messageId,
            'cancelledEmailReservedAt': FieldValue.delete(), // Clear lock
            'cancelledEmailFailedAt': FieldValue.delete(),   // Clear previous errors
            'cancelledEmailError': FieldValue.delete(),
          },
        }, SetOptions(merge: true));

        // Mark as processed in this session
        _processedOrders.add(orderId);
      } else {
        print('[CancelledOrderNotificationService] ❌ Email failed for $orderNo: ${result.error}');

        // PHASE 3b: Failure - mark as failed, clear lock to allow retry (after cooldown)
        await orderRef.set({
          'notifications': {
            'cancelledEmailFailedAt': FieldValue.serverTimestamp(),
            'cancelledEmailError': result.error ?? 'Unknown error',
            'cancelledEmailReservedAt': FieldValue.delete(), // Clear lock for retry
          },
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('[CancelledOrderNotificationService] ❌ Exception: $e');

      // Clear reservation to allow retry
      try {
        await orderRef.set({
          'notifications': {
            'cancelledEmailFailedAt': FieldValue.serverTimestamp(),
            'cancelledEmailError': 'Exception: $e',
            'cancelledEmailReservedAt': FieldValue.delete(),
          },
        }, SetOptions(merge: true));
      } catch (cleanupError) {
        print('[CancelledOrderNotificationService] ⚠️ Failed to clear reservation: $cleanupError');
      }
    }
  }

  /// Stop listening for cancelled orders
  void stopListening() {
    _ordersSubscription?.cancel();
    _ordersSubscription = null;
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    _serviceStartTime = null;
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
