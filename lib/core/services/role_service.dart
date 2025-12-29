import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_role.dart';
import '../branding/branding_providers.dart';

/// Provider for the current user's role data
final currentUserRoleProvider = StreamProvider<RoleData?>((ref) {
  final user = FirebaseAuth.instance.currentUser;

  // If no user is logged in, return null immediately
  if (user == null) {
    return Stream.value(null);
  }

  final merchantId = ref.watch(merchantIdProvider);
  final branchId = ref.watch(branchIdProvider);

  // If merchant/branch IDs aren't set yet, return null
  if (merchantId == null || branchId == null) {
    return Stream.value(null);
  }

  // Return the role document stream
  return FirebaseFirestore.instance
      .doc('merchants/$merchantId/branches/$branchId/roles/${user.uid}')
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) {
      // No role document means no access
      return null;
    }
    return RoleData.fromFirestore(doc.data()!);
  }).handleError((error) {
    // If there's a permission error, return null instead of crashing
    print('[RoleService] Error loading role: $error');
    return null;
  });
});

/// Provider to check if current user is admin
final isAdminProvider = Provider<bool>((ref) {
  final roleData = ref.watch(currentUserRoleProvider).value;
  return roleData?.isAdmin ?? false;
});

/// Provider to check if current user is staff
final isStaffProvider = Provider<bool>((ref) {
  final roleData = ref.watch(currentUserRoleProvider).value;
  return roleData?.isStaff ?? false;
});

/// Provider to check if current user can manage menu
final canManageMenuProvider = Provider<bool>((ref) {
  final roleData = ref.watch(currentUserRoleProvider).value;
  return roleData?.canManageMenu ?? false;
});

/// Provider to check if current user can view analytics
final canViewAnalyticsProvider = Provider<bool>((ref) {
  final roleData = ref.watch(currentUserRoleProvider).value;
  return roleData?.canViewAnalytics ?? false;
});

/// Provider to check if current user can manage users
final canManageUsersProvider = Provider<bool>((ref) {
  final roleData = ref.watch(currentUserRoleProvider).value;
  return roleData?.canManageUsers ?? false;
});

/// Service class for role-related operations
class RoleService {
  final FirebaseFirestore _firestore;
  final String merchantId;
  final String branchId;

  RoleService({
    required this.merchantId,
    required this.branchId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get the roles collection reference
  CollectionReference get _rolesCollection =>
      _firestore.doc('merchants/$merchantId/branches/$branchId').collection('roles');

  /// Get all users with their roles
  Stream<List<RoleData>> getAllUsers() {
    return _rolesCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RoleData.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  /// Get user role by userId
  Future<RoleData?> getUserRole(String userId) async {
    final doc = await _rolesCollection.doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return RoleData.fromFirestore(doc.data() as Map<String, dynamic>);
  }

  /// Add or update a user role
  Future<void> setUserRole({
    required String userId,
    required UserRole role,
    required String email,
    required String displayName,
    String? createdBy,
  }) async {
    final data = RoleData(
      role: role,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await _rolesCollection.doc(userId).set(data.toFirestore());
  }

  /// Remove a user's role (revoke access)
  Future<void> removeUser(String userId) async {
    await _rolesCollection.doc(userId).delete();
  }

  /// Update user's role
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    await _rolesCollection.doc(userId).update({
      'role': newRole.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Provider for RoleService
final roleServiceProvider = Provider<RoleService?>((ref) {
  final merchantId = ref.watch(merchantIdProvider);
  final branchId = ref.watch(branchIdProvider);

  if (merchantId == null || branchId == null) return null;

  return RoleService(
    merchantId: merchantId,
    branchId: branchId,
  );
});
