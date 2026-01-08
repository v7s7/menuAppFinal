import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/slug_routing.dart';
import 'checkout_fields_config.dart';

class CheckoutFieldsService {
  CheckoutFieldsService({
    required this.merchantId,
    required this.branchId,
  });

  final String merchantId;
  final String branchId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _configDoc {
    return _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(branchId)
        .collection('config')
        .doc('checkoutFields');
  }

  /// Watch checkout fields configuration (realtime updates)
  Stream<CheckoutFieldsConfig> watchCheckoutFieldsConfig() {
    return _configDoc.snapshots().map(
          (snapshot) => CheckoutFieldsConfig.fromFirestore(snapshot),
        );
  }

  /// Get checkout fields configuration (one-time read)
  Future<CheckoutFieldsConfig> getCheckoutFieldsConfig() async {
    final snapshot = await _configDoc.get();
    return CheckoutFieldsConfig.fromFirestore(snapshot);
  }

  /// Update checkout fields configuration (admin only)
  Future<void> updateCheckoutFieldsConfig(CheckoutFieldsConfig config) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final data = config.toFirestore();
    data['updatedBy'] = uid;

    await _configDoc.set(data, SetOptions(merge: true));
  }
}

/// Riverpod provider for CheckoutFieldsService
final checkoutFieldsServiceProvider = Provider<CheckoutFieldsService>((ref) {
  final ids = ref.watch(effectiveIdsProvider);
  if (ids == null) {
    throw StateError('Missing merchant/branch (provide ?m=&b= or a valid slug).');
  }
  return CheckoutFieldsService(
    merchantId: ids.merchantId,
    branchId: ids.branchId,
  );
});

/// Riverpod provider for watching checkout fields config (realtime)
final checkoutFieldsConfigProvider = StreamProvider<CheckoutFieldsConfig>((ref) {
  final service = ref.watch(checkoutFieldsServiceProvider);
  return service.watchCheckoutFieldsConfig();
});
