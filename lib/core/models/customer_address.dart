import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerAddress {
  final String id;
  final String? label;
  final String home;
  final String road;
  final String block;
  final String city;
  final String? flat;
  final String? notes;
  final DateTime? createdAt;

  const CustomerAddress({
    required this.id,
    this.label,
    required this.home,
    required this.road,
    required this.block,
    required this.city,
    this.flat,
    this.notes,
    this.createdAt,
  });

  factory CustomerAddress.fromMap(String id, Map<String, dynamic> map) {
    return CustomerAddress(
      id: id,
      label: map['label'] as String?,
      home: (map['home'] ?? '').toString(),
      road: (map['road'] ?? '').toString(),
      block: (map['block'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      flat: map['flat'] as String?,
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ??
          (map['savedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (label != null && label!.isNotEmpty) 'label': label,
      'home': home,
      'road': road,
      'block': block,
      'city': city,
      if (flat != null && flat!.isNotEmpty) 'flat': flat,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'createdAt': Timestamp.now(),
    };
  }
}
