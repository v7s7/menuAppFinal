import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'loyalty_models.dart';
import '../../../core/config/slug_routing.dart';

/// Service for managing loyalty points and customer profiles
class LoyaltyService {
  final String merchantId;
  final String branchId;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  LoyaltyService({required this.merchantId, required this.branchId});

  String get _m => merchantId;
  String get _b => branchId;

  /// Get customer profile by phone number
  Future<CustomerProfile?> getCustomerProfile(String phone) async {
    try {
      final doc = await _fs
          .collection('merchants')
          .doc(_m)
          .collection('branches')
          .doc(_b)
          .collection('customers')
          .doc(_normalizePhone(phone))
          .get();

      if (!doc.exists) return null;

      return CustomerProfile.fromMap(doc.data()!);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LoyaltyService] Error getting customer: $e\n$st');
      }
      return null;
    }
  }

  /// Stream customer profile
  Stream<CustomerProfile?> watchCustomerProfile(String phone) {
    return _fs
        .collection('merchants')
        .doc(_m)
        .collection('branches')
        .doc(_b)
        .collection('customers')
        .doc(_normalizePhone(phone))
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return CustomerProfile.fromMap(doc.data()!);
    });
  }

  /// Get loyalty settings
  Future<LoyaltySettings> getLoyaltySettings() async {
    try {
      final doc = await _fs
          .collection('merchants')
          .doc(_m)
          .collection('branches')
          .doc(_b)
          .collection('config')
          .doc('loyalty')
          .get();

      if (!doc.exists) {
        return LoyaltySettings.defaultSettings();
      }

      return LoyaltySettings.fromMap(doc.data()!);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LoyaltyService] Error getting settings: $e\n$st');
      }
      return LoyaltySettings.defaultSettings();
    }
  }

  /// Stream loyalty settings
  Stream<LoyaltySettings> watchLoyaltySettings() {
    return _fs
        .collection('merchants')
        .doc(_m)
        .collection('branches')
        .doc(_b)
        .collection('config')
        .doc('loyalty')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return LoyaltySettings.defaultSettings();
      }
      return LoyaltySettings.fromMap(doc.data()!);
    });
  }

  /// Update loyalty settings (merchant only)
  Future<void> updateLoyaltySettings(LoyaltySettings settings) async {
    try {
      await _fs
          .collection('merchants')
          .doc(_m)
          .collection('branches')
          .doc(_b)
          .collection('config')
          .doc('loyalty')
          .set(settings.toMap(), SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('[LoyaltyService] Settings updated');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LoyaltyService] Error updating settings: $e\n$st');
      }
      rethrow;
    }
  }

  /// Award points for an order (called after order creation)
  Future<void> awardPoints({
    required String phone,
    required String carPlate,
    required double orderAmount,
    required String orderId,
  }) async {
    try {
      final settings = await getLoyaltySettings();
      if (!settings.enabled) return;

      final pointsEarned = settings.calculatePointsEarned(orderAmount);
      if (pointsEarned <= 0) return;

      final normalizedPhone = _normalizePhone(phone);
      final normalizedCarPlate = carPlate.trim().toUpperCase();

      final customerRef = _fs
          .collection('merchants')
          .doc(_m)
          .collection('branches')
          .doc(_b)
          .collection('customers')
          .doc(normalizedPhone);

      await _fs.runTransaction((transaction) async {
        final customerDoc = await transaction.get(customerRef);

        if (customerDoc.exists) {
          // Update existing customer
          final current = CustomerProfile.fromMap(customerDoc.data()!);
          final updated = current.copyWith(
            carPlate: normalizedCarPlate,
            points: current.points + pointsEarned,
            totalSpent: current.totalSpent + orderAmount,
            orderCount: current.orderCount + 1,
            lastOrderAt: DateTime.now(),
          );
          transaction.update(customerRef, updated.toMap());
        } else {
          // Create new customer
          final newCustomer = CustomerProfile(
            phone: normalizedPhone,
            carPlate: normalizedCarPlate,
            points: pointsEarned,
            totalSpent: orderAmount,
            orderCount: 1,
            lastOrderAt: DateTime.now(),
          );
          transaction.set(customerRef, newCustomer.toMap());
        }

        // Log transaction
        final transactionRef = _fs
            .collection('merchants')
            .doc(_m)
            .collection('branches')
            .doc(_b)
            .collection('pointsTransactions')
            .doc();

        transaction.set(transactionRef, {
          'phone': normalizedPhone,
          'type': 'earned',
          'points': pointsEarned,
          'orderId': orderId,
          'createdAt': FieldValue.serverTimestamp(),
          'note': 'Earned $pointsEarned points from order $orderId',
        });
      });

      if (kDebugMode) {
        debugPrint('[LoyaltyService] Awarded $pointsEarned points to $normalizedPhone');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LoyaltyService] Error awarding points: $e\n$st');
      }
      rethrow;
    }
  }

  /// Redeem points (called during checkout)
  Future<void> redeemPoints({
    required String phone,
    required int pointsToRedeem,
    required String orderId,
  }) async {
    try {
      final settings = await getLoyaltySettings();
      if (!settings.enabled) {
        throw Exception('Loyalty program is not enabled');
      }

      if (pointsToRedeem < settings.minPointsToRedeem) {
        throw Exception('Minimum ${settings.minPointsToRedeem} points required to redeem');
      }

      final normalizedPhone = _normalizePhone(phone);
      final customerRef = _fs
          .collection('merchants')
          .doc(_m)
          .collection('branches')
          .doc(_b)
          .collection('customers')
          .doc(normalizedPhone);

      await _fs.runTransaction((transaction) async {
        final customerDoc = await transaction.get(customerRef);

        if (!customerDoc.exists) {
          throw Exception('Customer not found');
        }

        final current = CustomerProfile.fromMap(customerDoc.data()!);

        if (current.points < pointsToRedeem) {
          throw Exception('Insufficient points (have: ${current.points}, need: $pointsToRedeem)');
        }

        // Deduct points
        final updated = current.copyWith(points: current.points - pointsToRedeem);
        transaction.update(customerRef, updated.toMap());

        // Log transaction
        final transactionRef = _fs
            .collection('merchants')
            .doc(_m)
            .collection('branches')
            .doc(_b)
            .collection('pointsTransactions')
            .doc();

        transaction.set(transactionRef, {
          'phone': normalizedPhone,
          'type': 'redeemed',
          'points': -pointsToRedeem,
          'orderId': orderId,
          'createdAt': FieldValue.serverTimestamp(),
          'note': 'Redeemed $pointsToRedeem points for order $orderId',
        });
      });

      if (kDebugMode) {
        debugPrint('[LoyaltyService] Redeemed $pointsToRedeem points from $normalizedPhone');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LoyaltyService] Error redeeming points: $e\n$st');
      }
      rethrow;
    }
  }

  /// Get all customers (for merchant view)
  Stream<List<CustomerProfile>> watchAllCustomers({int limit = 100}) {
    return _fs
        .collection('merchants')
        .doc(_m)
        .collection('branches')
        .doc(_b)
        .collection('customers')
        .orderBy('lastOrderAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CustomerProfile.fromMap(doc.data())).toList();
    });
  }

  /// Normalize phone number (remove spaces, dashes, etc.)
  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }
}

/// Provider for loyalty service
final loyaltyServiceProvider = Provider<LoyaltyService>((ref) {
  final ids = ref.watch(effectiveIdsProvider);
  if (ids == null) {
    throw StateError('Missing merchant/branch IDs');
  }
  return LoyaltyService(
    merchantId: ids.merchantId,
    branchId: ids.branchId,
  );
});

/// Provider for loyalty settings stream
final loyaltySettingsProvider = StreamProvider<LoyaltySettings>((ref) {
  final service = ref.watch(loyaltyServiceProvider);
  return service.watchLoyaltySettings();
});

/// Provider for customer profile by phone
final customerProfileProvider = StreamProvider.family<CustomerProfile?, String>((ref, phone) {
  if (phone.isEmpty) return Stream.value(null);
  final service = ref.watch(loyaltyServiceProvider);
  return service.watchCustomerProfile(phone);
});

/// Provider for all customers (merchant view)
final allCustomersProvider = StreamProvider<List<CustomerProfile>>((ref) {
  final service = ref.watch(loyaltyServiceProvider);
  return service.watchAllCustomers();
});
