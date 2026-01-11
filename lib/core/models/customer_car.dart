import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerCar {
  final String id;
  final String plate;
  final String? note;
  final DateTime? createdAt;

  const CustomerCar({
    required this.id,
    required this.plate,
    this.note,
    this.createdAt,
  });

  factory CustomerCar.fromMap(String id, Map<String, dynamic> map) {
    return CustomerCar(
      id: id,
      plate: (map['plate'] ?? '').toString(),
      note: map['note'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plate': plate,
      if (note != null && note!.isNotEmpty) 'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
