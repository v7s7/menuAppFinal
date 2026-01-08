/// Bahrain address model for delivery/checkout
///
/// Required fields: home (building number), road, block, city
/// Optional fields: flat, notes
class BahrainAddress {
  final String home; // Building/Home number (required)
  final String road; // Road number (required)
  final String block; // Block number (required)
  final String city; // City name (required)
  final String? flat; // Flat/Apartment number (optional)
  final String? notes; // Additional delivery notes (optional)

  const BahrainAddress({
    required this.home,
    required this.road,
    required this.block,
    required this.city,
    this.flat,
    this.notes,
  });

  /// Validates that all required fields are non-empty
  bool get isValid {
    return home.trim().isNotEmpty &&
        road.trim().isNotEmpty &&
        block.trim().isNotEmpty &&
        city.trim().isNotEmpty;
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'home': home,
      'road': road,
      'block': block,
      'city': city,
      if (flat != null && flat!.trim().isNotEmpty) 'flat': flat,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
    };
  }

  /// Create from Firestore map (with backward compatibility for old data without city)
  factory BahrainAddress.fromMap(Map<String, dynamic> map) {
    return BahrainAddress(
      home: map['home'] as String? ?? '',
      road: map['road'] as String? ?? '',
      block: map['block'] as String? ?? '',
      city: map['city'] as String? ?? '', // Backward compatible: defaults to empty if missing
      flat: map['flat'] as String?,
      notes: map['notes'] as String?,
    );
  }

  /// Format address for display
  /// Example: "Flat 12, Home 45, Road 12, Block 340, Manama"
  String toDisplayString() {
    final parts = <String>[];

    if (flat != null && flat!.trim().isNotEmpty) {
      parts.add('Flat ${flat!.trim()}');
    }

    if (home.trim().isNotEmpty) {
      parts.add('Home ${home.trim()}');
    }

    if (road.trim().isNotEmpty) {
      parts.add('Road ${road.trim()}');
    }

    if (block.trim().isNotEmpty) {
      parts.add('Block ${block.trim()}');
    }

    if (city.trim().isNotEmpty) {
      parts.add(city.trim());
    }

    return parts.join(', ');
  }

  /// Copy with method for creating modified instances
  BahrainAddress copyWith({
    String? home,
    String? road,
    String? block,
    String? city,
    String? flat,
    String? notes,
  }) {
    return BahrainAddress(
      home: home ?? this.home,
      road: road ?? this.road,
      block: block ?? this.block,
      city: city ?? this.city,
      flat: flat ?? this.flat,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() => toDisplayString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BahrainAddress &&
        other.home == home &&
        other.road == road &&
        other.block == block &&
        other.city == city &&
        other.flat == flat &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(home, road, block, city, flat, notes);
  }
}
