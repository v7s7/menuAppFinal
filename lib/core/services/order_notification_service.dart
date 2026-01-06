import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'email_service.dart';

/// Service to listen for new orders and send email notifications
/// Emails are sent ONLY to the merchant's configured email address
class OrderNotificationService {
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

  /// Start listening for new orders
  /// Loads merchant's email configuration from Firestore settings
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

    print('[OrderNotificationService] Starting for merchant: $merchantId, branch: $branchId');

    // Load email settings
    final settingsValid = await _loadEmailSettings();
    if (!settingsValid) {
      print('[OrderNotificationService] ⚠️ Email notifications NOT started - email not configured or disabled');
      return;
    }

    print('[OrderNotificationService] ✅ Email notifications enabled, sending to: $_merchantEmail');

    // Start settings listener for live updates
    _startSettingsListener();

    // Start listening to pending orders
    // NO createdAt filter - rely on transaction markers to prevent historical duplicates
    // This ensures we never miss pending order emails
    _ordersSubscription = FirebaseFirestore.instance
        .collection('merchants/$merchantId/branches/$branchId/orders')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final orderId = change.doc.id;

          // Do NOT check _processedOrders here - allow retries

          _sendOrderNotification(orderId: orderId, orderData: change.doc.data()!);
        }
      }
    });
  }

  /// Load and validate email settings from Firestore
  Future<bool> _loadEmailSettings() async {
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .doc('merchants/$_merchantId/branches/$_branchId/config/settings')
          .get();

      if (!settingsDoc.exists) {
        return false;
      }

      final emailData = settingsDoc.data()?['emailNotifications'] as Map<String, dynamic>?;
      if (emailData == null) {
        return false;
      }

      _emailEnabled = emailData['enabled'] as bool? ?? false;
      final email = emailData['email'] as String?;

      if (!_emailEnabled || email == null || email.trim().isEmpty) {
        return false;
      }

      if (!_isValidEmail(email.trim())) {
        print('[OrderNotificationService] ⚠️ Invalid email format: $email');
        return false;
      }

      _merchantEmail = email.trim();
      return true;
    } catch (e) {
      print('[OrderNotificationService] ❌ Failed to load settings: $e');
      return false;
    }
  }

  /// Listen to settings for live updates
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
          print('[OrderNotificationService] 🔄 Email updated: $_merchantEmail → $newEmail');
          _merchantEmail = newEmail;
          _emailEnabled = true;
        }
      } else if (!enabled && _emailEnabled) {
        print('[OrderNotificationService] ⚠️ Notifications disabled');
        _emailEnabled = false;
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email);
  }

  /// Send email notification for new order
  /// Two-phase idempotency with 10-minute lock TTL and 2-minute failure cooldown
  Future<void> _sendOrderNotification({
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
      // PHASE 1: Transaction with lock TTL and failure cooldown
      final shouldSend = await FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
        final freshDoc = await transaction.get(orderRef);
        if (!freshDoc.exists) return false;

        final notifications = freshDoc.data()?['notifications'] as Map<String, dynamic>?;

        // Already sent successfully? Skip
        if (notifications?['pendingEmailSentAt'] != null) {
          return false;
        }

        // FAILURE COOLDOWN: If recently failed, wait before retry (prevent infinite loops)
        final failedAt = notifications?['pendingEmailFailedAt'] as Timestamp?;
        if (failedAt != null) {
          final timeSinceFailure = DateTime.now().difference(failedAt.toDate());
          if (timeSinceFailure.inSeconds < 120) {
            // Too soon after failure - skip to prevent rapid retry loops
            return false;
          }
        }

        // LOCK TTL: Check reservation with 10-minute timeout (clock drift safety)
        final reservedAt = notifications?['pendingEmailReservedAt'] as Timestamp?;
        if (reservedAt != null) {
          final age = DateTime.now().difference(reservedAt.toDate());
          if (age.inMinutes < 10) {
            // Lock is fresh - another process is actively sending
            return false;
          }
          // Lock is stale (>10 min) - treat as abandoned, proceed to re-reserve
          print('[OrderNotificationService] ⚠️ Stale lock detected (${age.inMinutes} min old), re-reserving');
        }

        // Reserve (or re-reserve if stale)
        transaction.set(
          orderRef,
          {
            'notifications': {
              'pendingEmailReservedAt': FieldValue.serverTimestamp(),
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
        print('[OrderNotificationService] ⚠️ Email disabled after reservation, clearing lock');
        await orderRef.set({
          'notifications': {
            'pendingEmailReservedAt': FieldValue.delete(),
          },
        }, SetOptions(merge: true));
        return;
      }

      // PHASE 2: Send email
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
        merchantName: _merchantName ?? 'Your Store',
        dashboardUrl: 'https://sweetweb.web.app/merchant',
        toEmail: _merchantEmail!,
      );

      if (result.success) {
        print('[OrderNotificationService] ✅ Email sent for $orderNo to $_merchantEmail: ${result.messageId}');

        // PHASE 3a: Success - mark as sent, clear lock and errors
        await orderRef.set({
          'notifications': {
            'pendingEmailSentAt': FieldValue.serverTimestamp(),
            'pendingEmailMessageId': result.messageId,
            'pendingEmailReservedAt': FieldValue.delete(), // Clear lock
            'pendingEmailFailedAt': FieldValue.delete(),   // Clear previous errors
            'pendingEmailError': FieldValue.delete(),
          },
        }, SetOptions(merge: true));

        // Mark as processed in memory to prevent re-processing in this session
        _processedOrders.add(orderId);
      } else {
        print('[OrderNotificationService] ❌ Email failed for $orderNo: ${result.error}');

        // PHASE 3b: Failure - mark as failed, clear lock to allow retry (after cooldown)
        await orderRef.set({
          'notifications': {
            'pendingEmailFailedAt': FieldValue.serverTimestamp(),
            'pendingEmailError': result.error ?? 'Unknown error',
            'pendingEmailReservedAt': FieldValue.delete(), // Clear lock for retry
          },
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('[OrderNotificationService] ❌ Exception sending notification: $e');

      // Clear reservation to allow retry
      try {
        await orderRef.set({
          'notifications': {
            'pendingEmailFailedAt': FieldValue.serverTimestamp(),
            'pendingEmailError': 'Exception: $e',
            'pendingEmailReservedAt': FieldValue.delete(),
          },
        }, SetOptions(merge: true));
      } catch (cleanupError) {
        print('[OrderNotificationService] ⚠️ Failed to clear reservation: $cleanupError');
      }
    }
  }

  /// Stop listening for new orders
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
