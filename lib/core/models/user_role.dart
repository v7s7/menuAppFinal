import 'package:cloud_firestore/cloud_firestore.dart';

/// User roles in the merchant system
enum UserRole {
  admin,
  staff;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.staff; // Default to staff for safety
    }
  }
}

/// Role document data from Firestore
class RoleData {
  final UserRole role;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final String? createdBy;

  const RoleData({
    required this.role,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.createdBy,
  });

  factory RoleData.fromFirestore(Map<String, dynamic> data) {
    return RoleData(
      role: UserRole.fromString(data['role'] as String? ?? 'staff'),
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role.name,
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  /// Check if this role can manage menu (products, categories, branding)
  bool get canManageMenu => role == UserRole.admin;

  /// Check if this role can view analytics
  bool get canViewAnalytics => role == UserRole.admin;

  /// Check if this role can manage users
  bool get canManageUsers => role == UserRole.admin;

  /// Check if this role can view orders
  bool get canViewOrders => true; // Both admin and staff

  /// Check if this role can modify order status
  bool get canModifyOrders => true; // Both admin and staff

  /// Check if this role is admin
  bool get isAdmin => role == UserRole.admin;

  /// Check if this role is staff
  bool get isStaff => role == UserRole.staff;
}
