import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer profile with loyalty points
class CustomerProfile {
  final String phone; // Primary identifier (for loyalty points)
  final String carPlate; // Car plate (for restaurant to identify customer)
  final int points; // Current points balance
  final double totalSpent; // Lifetime spending (BHD)
  final int orderCount; // Total orders placed
  final DateTime? lastOrderAt; // Last order timestamp

  const CustomerProfile({
    required this.phone,
    required this.carPlate,
    required this.points,
    required this.totalSpent,
    required this.orderCount,
    this.lastOrderAt,
  });

  factory CustomerProfile.fromMap(Map<String, dynamic> map) {
    return CustomerProfile(
      phone: (map['phone'] as String?) ?? '',
      carPlate: ((map['carPlate'] as String?) ?? '').trim(),
      points: (map['points'] as num?)?.toInt() ?? 0,
      totalSpent: ((map['totalSpent'] as num?) ?? 0).toDouble(),
      orderCount: (map['orderCount'] as num?)?.toInt() ?? 0,
      lastOrderAt: (map['lastOrderAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'phone': phone,
        'carPlate': carPlate,
        'points': points,
        'totalSpent': totalSpent,
        'orderCount': orderCount,
        'lastOrderAt': lastOrderAt != null ? Timestamp.fromDate(lastOrderAt!) : null,
      };

  CustomerProfile copyWith({
    String? phone,
    String? carPlate,
    int? points,
    double? totalSpent,
    int? orderCount,
    DateTime? lastOrderAt,
  }) {
    return CustomerProfile(
      phone: phone ?? this.phone,
      carPlate: carPlate ?? this.carPlate,
      points: points ?? this.points,
      totalSpent: totalSpent ?? this.totalSpent,
      orderCount: orderCount ?? this.orderCount,
      lastOrderAt: lastOrderAt ?? this.lastOrderAt,
    );
  }
}

/// Loyalty program settings (configured by merchant)
class LoyaltySettings {
  final bool enabled; // Is loyalty program active?
  final int earnRate; // Points earned per 1 BHD spent (default: 10)
  final int redeemRate; // Points needed for 1 BHD discount (default: 50)
  final double minOrderAmount; // Minimum order to use points (BHD)
  final double maxDiscountAmount; // Maximum discount per order (BHD)
  final int minPointsToRedeem; // Minimum points needed to redeem

  const LoyaltySettings({
    required this.enabled,
    required this.earnRate,
    required this.redeemRate,
    required this.minOrderAmount,
    required this.maxDiscountAmount,
    required this.minPointsToRedeem,
  });

  factory LoyaltySettings.fromMap(Map<String, dynamic> map) {
    return LoyaltySettings(
      enabled: (map['enabled'] as bool?) ?? false,
      earnRate: (map['earnRate'] as num?)?.toInt() ?? 10,
      redeemRate: (map['redeemRate'] as num?)?.toInt() ?? 50,
      minOrderAmount: ((map['minOrderAmount'] as num?) ?? 5).toDouble(),
      maxDiscountAmount: ((map['maxDiscountAmount'] as num?) ?? 10).toDouble(),
      minPointsToRedeem: (map['minPointsToRedeem'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'earnRate': earnRate,
        'redeemRate': redeemRate,
        'minOrderAmount': minOrderAmount,
        'maxDiscountAmount': maxDiscountAmount,
        'minPointsToRedeem': minPointsToRedeem,
      };

  factory LoyaltySettings.defaultSettings() => const LoyaltySettings(
        enabled: false, // Disabled by default - merchant must enable
        earnRate: 10, // 10 points per 1 BHD
        redeemRate: 50, // 50 points = 1 BHD discount
        minOrderAmount: 5.0, // 5 BHD minimum
        maxDiscountAmount: 10.0, // Max 10 BHD discount
        minPointsToRedeem: 50, // Need at least 50 points
      );

  LoyaltySettings copyWith({
    bool? enabled,
    int? earnRate,
    int? redeemRate,
    double? minOrderAmount,
    double? maxDiscountAmount,
    int? minPointsToRedeem,
  }) {
    return LoyaltySettings(
      enabled: enabled ?? this.enabled,
      earnRate: earnRate ?? this.earnRate,
      redeemRate: redeemRate ?? this.redeemRate,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      minPointsToRedeem: minPointsToRedeem ?? this.minPointsToRedeem,
    );
  }

  /// Calculate points earned for an order amount
  int calculatePointsEarned(double orderAmount) {
    return (orderAmount * earnRate).round();
  }

  /// Calculate discount amount from points
  double calculateDiscount(int points) {
    if (points < minPointsToRedeem) return 0.0;
    return (points / redeemRate).floorToDouble();
  }

  /// Calculate maximum usable points for an order
  int calculateMaxUsablePoints(double orderAmount) {
    // Can't use points if order is below minimum
    if (orderAmount < minOrderAmount) return 0;

    // Calculate max discount based on settings
    final maxDiscount = maxDiscountAmount < orderAmount ? maxDiscountAmount : orderAmount;

    // Convert max discount to points
    final maxPoints = (maxDiscount * redeemRate).floor();

    return maxPoints;
  }

  /// Validate if points can be used for this order
  bool canUsePoints(double orderAmount, int pointsToUse) {
    if (!enabled) return false;
    if (orderAmount < minOrderAmount) return false;
    if (pointsToUse < minPointsToRedeem) return false;

    final discount = calculateDiscount(pointsToUse);
    if (discount > maxDiscountAmount) return false;
    if (discount > orderAmount) return false;

    return true;
  }
}

/// Points transaction record (for audit trail)
class PointsTransaction {
  final String transactionId;
  final String phone;
  final String type; // 'earned' or 'redeemed'
  final int points;
  final String? orderId;
  final DateTime createdAt;
  final String? note;

  const PointsTransaction({
    required this.transactionId,
    required this.phone,
    required this.type,
    required this.points,
    this.orderId,
    required this.createdAt,
    this.note,
  });

  factory PointsTransaction.fromMap(Map<String, dynamic> map, String id) {
    return PointsTransaction(
      transactionId: id,
      phone: (map['phone'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'earned',
      points: (map['points'] as num?)?.toInt() ?? 0,
      orderId: (map['orderId'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: (map['note'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
        'phone': phone,
        'type': type,
        'points': points,
        'orderId': orderId,
        'createdAt': Timestamp.fromDate(createdAt),
        'note': note,
      };
}

/// Checkout data with loyalty information
class CheckoutData {
  final String phone;
  final String carPlate;
  final int pointsToUse; // Points customer wants to redeem
  final double discount; // Calculated discount from points

  const CheckoutData({
    required this.phone,
    required this.carPlate,
    required this.pointsToUse,
    required this.discount,
  });

  CheckoutData copyWith({
    String? phone,
    String? carPlate,
    int? pointsToUse,
    double? discount,
  }) {
    return CheckoutData(
      phone: phone ?? this.phone,
      carPlate: carPlate ?? this.carPlate,
      pointsToUse: pointsToUse ?? this.pointsToUse,
      discount: discount ?? this.discount,
    );
  }
}
