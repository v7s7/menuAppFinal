import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String phoneE164;
  final String? displayName;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.phoneE164,
    required this.createdAt,
    this.displayName,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      phoneE164: (map['phoneE164'] ?? '').toString(),
      displayName: map['displayName'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phoneE164': phoneE164,
      if (displayName != null && displayName!.isNotEmpty) 'displayName': displayName,
      'createdAt': createdAt,
    };
  }
}
