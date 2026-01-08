import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration for which fields are required at checkout
class CheckoutFieldsConfig {
  final bool phoneRequired;
  final bool plateNumberRequired;
  final bool tableRequired;
  final bool addressRequired;

  const CheckoutFieldsConfig({
    this.phoneRequired = true, // Default: phone required (backward compatible)
    this.plateNumberRequired = true, // Default: plate required (backward compatible)
    this.tableRequired = false, // Default: table not required
    this.addressRequired = false, // Default: address not required
  });

  /// Create from Firestore document
  factory CheckoutFieldsConfig.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      return const CheckoutFieldsConfig(); // Return defaults
    }

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return const CheckoutFieldsConfig();
    }

    return CheckoutFieldsConfig(
      phoneRequired: data['phoneRequired'] ?? true,
      plateNumberRequired: data['plateNumberRequired'] ?? true,
      tableRequired: data['tableRequired'] ?? false,
      addressRequired: data['addressRequired'] ?? false,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'phoneRequired': phoneRequired,
      'plateNumberRequired': plateNumberRequired,
      'tableRequired': tableRequired,
      'addressRequired': addressRequired,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Check if at least one customer identification field is required
  bool get hasIdentificationField {
    return phoneRequired || plateNumberRequired || tableRequired || addressRequired;
  }

  CheckoutFieldsConfig copyWith({
    bool? phoneRequired,
    bool? plateNumberRequired,
    bool? tableRequired,
    bool? addressRequired,
  }) {
    return CheckoutFieldsConfig(
      phoneRequired: phoneRequired ?? this.phoneRequired,
      plateNumberRequired: plateNumberRequired ?? this.plateNumberRequired,
      tableRequired: tableRequired ?? this.tableRequired,
      addressRequired: addressRequired ?? this.addressRequired,
    );
  }
}

/// Bahrain home address model
class BahrainAddress {
  final String home; // Building number
  final String road;
  final String block;
  final String? flat; // Optional
  final String? notes; // Optional extra notes

  const BahrainAddress({
    required this.home,
    required this.road,
    required this.block,
    this.flat,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'home': home,
      'road': road,
      'block': block,
      if (flat != null && flat!.isNotEmpty) 'flat': flat,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  factory BahrainAddress.fromMap(Map<String, dynamic> map) {
    return BahrainAddress(
      home: map['home'] ?? '',
      road: map['road'] ?? '',
      block: map['block'] ?? '',
      flat: map['flat'],
      notes: map['notes'],
    );
  }

  bool get isValid {
    return home.trim().isNotEmpty &&
        road.trim().isNotEmpty &&
        block.trim().isNotEmpty;
  }

  @override
  String toString() {
    final parts = <String>[
      if (flat != null && flat!.isNotEmpty) 'Flat $flat,',
      'Building $home,',
      'Road $road,',
      'Block $block',
    ];
    return parts.join(' ');
  }
}
