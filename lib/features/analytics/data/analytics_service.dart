import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_models.dart';
import '../../orders/data/order_models.dart' as om;
import '../../sweets/data/sweet.dart';
import '../../categories/data/category.dart' as cat;
import '../../../core/config/slug_routing.dart';

/// Service for computing analytics from orders
class AnalyticsService {
  AnalyticsService({
    required this.merchantId,
    required this.branchId,
  });

  final String merchantId;
  final String branchId;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  String get _m => merchantId;
  String get _b => branchId;

  /// Compute complete analytics dashboard for a date range
  Future<AnalyticsDashboard> computeAnalytics({
    required DateRange dateRange,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    try {
      // Get date boundaries
      final DateTime startDate;
      final DateTime endDate;

      if (dateRange == DateRange.custom && customStart != null && customEnd != null) {
        startDate = customStart;
        endDate = customEnd;
      } else {
        final dates = dateRange.getDates();
        startDate = dates.start;
        endDate = dates.end;
      }

      if (kDebugMode) {
        debugPrint('[Analytics] Computing for $startDate to $endDate');
      }

      // Fetch orders in date range
      final ordersQuery = _fs
          .collection('merchants')
          .doc(_m)
          .collection('branches')
          .doc(_b)
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true);

      final ordersSnapshot = await ordersQuery.get();

      if (kDebugMode) {
        debugPrint('[Analytics] Found ${ordersSnapshot.docs.length} orders');
      }

      // Fetch products and categories for enrichment
      final products = await _fetchProducts();
      final categories = await _fetchCategories();

      // Parse orders
      final orders = ordersSnapshot.docs.map(_parseOrder).toList();

      // Compute all metrics
      final sales = _computeSalesAnalytics(orders);
      final productPerf = _computeProductPerformance(orders, products);
      final categoryPerf = _computeCategoryPerformance(orders, products, categories);
      final hourly = _computeHourlyDistribution(orders);
      final daily = _computeDailyTrends(orders, startDate, endDate);
      final customerInsights = _computeCustomerInsights(orders, startDate);

      return AnalyticsDashboard(
        dateRange: dateRange,
        startDate: startDate,
        endDate: endDate,
        sales: sales,
        topProducts: productPerf.take(10).toList(),
        slowMovingProducts: productPerf.reversed.take(10).toList(),
        categoryPerformance: categoryPerf,
        hourlyDistribution: hourly,
        dailyTrends: daily,
        customerInsights: customerInsights,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Analytics] Error: $e\n$st');
      }
      return AnalyticsDashboard.empty(dateRange);
    }
  }

  /// Fetch all products for the branch
  Future<Map<String, Sweet>> _fetchProducts() async {
    final snapshot = await _fs
        .collection('merchants')
        .doc(_m)
        .collection('branches')
        .doc(_b)
        .collection('menuItems')
        .get();

    return Map.fromEntries(
      snapshot.docs.map((doc) => MapEntry(doc.id, Sweet.fromMap(doc.data(), id: doc.id))),
    );
  }

  /// Fetch all categories for the branch
  Future<Map<String, cat.Category>> _fetchCategories() async {
    final snapshot = await _fs
        .collection('merchants')
        .doc(_m)
        .collection('branches')
        .doc(_b)
        .collection('categories')
        .get();

    return Map.fromEntries(
      snapshot.docs.map((doc) => MapEntry(doc.id, cat.Category.fromDoc(doc.id, doc.data()))),
    );
  }

  /// Parse Firestore order document
  _OrderData _parseOrder(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final statusStr = (data['status'] as String?) ?? 'pending';
    final status = _parseStatus(statusStr);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final userId = (data['userId'] as String?) ?? '';
    final subtotal = ((data['subtotal'] as num?) ?? 0).toDouble();

    final rawItems = (data['items'] as List<dynamic>?) ?? [];
    final items = rawItems.whereType<Map<String, dynamic>>().map((m) {
      return _OrderItemData(
        productId: (m['productId'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        price: ((m['price'] as num?) ?? 0).toDouble(),
        qty: ((m['qty'] as num?) ?? 0).toInt(),
      );
    }).toList();

    return _OrderData(
      orderId: doc.id,
      status: status,
      createdAt: createdAt,
      userId: userId,
      subtotal: subtotal,
      items: items,
    );
  }

  om.OrderStatus _parseStatus(String s) {
    switch (s) {
      case 'pending': return om.OrderStatus.pending;
      case 'accepted': return om.OrderStatus.accepted;
      case 'preparing': return om.OrderStatus.preparing;
      case 'ready': return om.OrderStatus.ready;
      case 'served': return om.OrderStatus.served;
      case 'cancelled': return om.OrderStatus.cancelled;
      default: return om.OrderStatus.pending;
    }
  }

  /// Compute sales analytics
  SalesAnalytics _computeSalesAnalytics(List<_OrderData> orders) {
    if (orders.isEmpty) return SalesAnalytics.empty();

    final completedStatuses = {
      om.OrderStatus.served,
      om.OrderStatus.ready,
      om.OrderStatus.preparing,
      om.OrderStatus.accepted,
    };

    final completedOrders = orders.where((o) => completedStatuses.contains(o.status)).toList();
    final cancelledOrders = orders.where((o) => o.status == om.OrderStatus.cancelled).toList();

    final totalRevenue = completedOrders.fold<double>(0, (sum, o) => sum + o.subtotal);
    final totalItems = completedOrders.fold<int>(
      0,
      (sum, o) => sum + o.items.fold<int>(0, (s, i) => s + i.qty),
    );

    final avgOrderValue = completedOrders.isEmpty ? 0.0 : totalRevenue / completedOrders.length;
    final completionRate = orders.isEmpty ? 0.0 : (completedOrders.length / orders.length) * 100;

    return SalesAnalytics(
      totalRevenue: double.parse(totalRevenue.toStringAsFixed(3)),
      totalOrders: orders.length,
      totalItems: totalItems,
      averageOrderValue: double.parse(avgOrderValue.toStringAsFixed(3)),
      completedOrders: completedOrders.length,
      cancelledOrders: cancelledOrders.length,
      completionRate: double.parse(completionRate.toStringAsFixed(1)),
    );
  }

  /// Compute product performance
  List<ProductPerformance> _computeProductPerformance(
    List<_OrderData> orders,
    Map<String, Sweet> products,
  ) {
    final completedStatuses = {
      om.OrderStatus.served,
      om.OrderStatus.ready,
      om.OrderStatus.preparing,
      om.OrderStatus.accepted,
    };

    final completedOrders = orders.where((o) => completedStatuses.contains(o.status)).toList();

    // Aggregate by product
    final Map<String, _ProductStats> stats = {};

    for (final order in completedOrders) {
      for (final item in order.items) {
        final existing = stats[item.productId] ?? _ProductStats();
        stats[item.productId] = _ProductStats(
          quantitySold: existing.quantitySold + item.qty,
          revenue: existing.revenue + (item.price * item.qty),
          orderCount: existing.orderCount + 1,
        );
      }
    }

    // Convert to performance objects
    final performances = stats.entries.map((e) {
      final product = products[e.key];
      final name = product?.name ?? 'Unknown Product';
      final avgQty = e.value.orderCount > 0
          ? e.value.quantitySold / e.value.orderCount
          : 0.0;

      return ProductPerformance(
        productId: e.key,
        productName: name,
        quantitySold: e.value.quantitySold,
        revenue: double.parse(e.value.revenue.toStringAsFixed(3)),
        orderCount: e.value.orderCount,
        averageQuantityPerOrder: double.parse(avgQty.toStringAsFixed(2)),
      );
    }).toList();

    // Sort by revenue descending
    performances.sort((a, b) => b.revenue.compareTo(a.revenue));

    return performances;
  }

  /// Compute category performance
  List<CategoryPerformance> _computeCategoryPerformance(
    List<_OrderData> orders,
    Map<String, Sweet> products,
    Map<String, cat.Category> categories,
  ) {
    final completedStatuses = {
      om.OrderStatus.served,
      om.OrderStatus.ready,
      om.OrderStatus.preparing,
      om.OrderStatus.accepted,
    };

    final completedOrders = orders.where((o) => completedStatuses.contains(o.status)).toList();

    // Aggregate by category
    final Map<String, _CategoryStats> stats = {};
    double totalRevenue = 0;

    for (final order in completedOrders) {
      for (final item in order.items) {
        final product = products[item.productId];
        final categoryId = product?.categoryId ?? 'uncategorized';
        final revenue = item.price * item.qty;
        totalRevenue += revenue;

        final existing = stats[categoryId] ?? _CategoryStats();
        stats[categoryId] = _CategoryStats(
          quantitySold: existing.quantitySold + item.qty,
          revenue: existing.revenue + revenue,
          productIds: {...existing.productIds, item.productId},
        );
      }
    }

    // Convert to performance objects
    final performances = stats.entries.map((e) {
      final category = categories[e.key];
      final name = category?.name ?? 'Uncategorized';
      final revenueShare = totalRevenue > 0 ? (e.value.revenue / totalRevenue) * 100 : 0.0;

      return CategoryPerformance(
        categoryId: e.key,
        categoryName: name,
        quantitySold: e.value.quantitySold,
        revenue: double.parse(e.value.revenue.toStringAsFixed(3)),
        productCount: e.value.productIds.length,
        revenueShare: double.parse(revenueShare.toStringAsFixed(1)),
      );
    }).toList();

    // Sort by revenue descending
    performances.sort((a, b) => b.revenue.compareTo(a.revenue));

    return performances;
  }

  /// Compute hourly distribution
  List<HourlyDistribution> _computeHourlyDistribution(List<_OrderData> orders) {
    final Map<int, _HourStats> hourStats = {};

    for (final order in orders) {
      final hour = order.createdAt.hour;
      final existing = hourStats[hour] ?? _HourStats();
      hourStats[hour] = _HourStats(
        orderCount: existing.orderCount + 1,
        revenue: existing.revenue + order.subtotal,
      );
    }

    // Create list for all 24 hours
    return List.generate(24, (hour) {
      final stats = hourStats[hour] ?? _HourStats();
      return HourlyDistribution(
        hour: hour,
        orderCount: stats.orderCount,
        revenue: double.parse(stats.revenue.toStringAsFixed(3)),
      );
    });
  }

  /// Compute daily trends
  List<DailyTrend> _computeDailyTrends(
    List<_OrderData> orders,
    DateTime startDate,
    DateTime endDate,
  ) {
    final completedStatuses = {
      om.OrderStatus.served,
      om.OrderStatus.ready,
      om.OrderStatus.preparing,
      om.OrderStatus.accepted,
    };

    final completedOrders = orders.where((o) => completedStatuses.contains(o.status)).toList();

    // Aggregate by date
    final Map<String, _DayStats> dayStats = {};

    for (final order in completedOrders) {
      final dateKey = _dateKey(order.createdAt);
      final existing = dayStats[dateKey] ?? _DayStats(date: order.createdAt);
      dayStats[dateKey] = _DayStats(
        date: order.createdAt,
        revenue: existing.revenue + order.subtotal,
        orderCount: existing.orderCount + 1,
      );
    }

    // Fill in missing days with zero values
    final days = endDate.difference(startDate).inDays + 1;
    final trends = <DailyTrend>[];

    for (var i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = _dateKey(date);
      final stats = dayStats[dateKey] ?? _DayStats(date: date);

      trends.add(DailyTrend(
        date: DateTime(date.year, date.month, date.day),
        revenue: double.parse(stats.revenue.toStringAsFixed(3)),
        orderCount: stats.orderCount,
      ));
    }

    return trends;
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  /// Compute customer insights
  CustomerInsights _computeCustomerInsights(
    List<_OrderData> orders,
    DateTime periodStart,
  ) {
    if (orders.isEmpty) return CustomerInsights.empty();

    // Group orders by user
    final Map<String, List<_OrderData>> ordersByUser = {};
    for (final order in orders) {
      ordersByUser.putIfAbsent(order.userId, () => []).add(order);
    }

    final totalCustomers = ordersByUser.length;

    // Determine new vs returning (need orders before period start)
    // For now, simplified: users with 1 order = new, >1 = returning
    int newCustomers = 0;
    int returningCustomers = 0;

    for (final userOrders in ordersByUser.values) {
      if (userOrders.length == 1) {
        newCustomers++;
      } else {
        returningCustomers++;
      }
    }

    final retentionRate = totalCustomers > 0
        ? (returningCustomers / totalCustomers) * 100
        : 0.0;

    final totalOrders = orders.length;
    final avgOrdersPerCustomer = totalCustomers > 0
        ? totalOrders / totalCustomers
        : 0.0;

    final totalRevenue = orders.fold<double>(0, (sum, o) => sum + o.subtotal);
    final avgLifetimeValue = totalCustomers > 0
        ? totalRevenue / totalCustomers
        : 0.0;

    return CustomerInsights(
      totalCustomers: totalCustomers,
      newCustomers: newCustomers,
      returningCustomers: returningCustomers,
      customerRetentionRate: double.parse(retentionRate.toStringAsFixed(1)),
      averageOrdersPerCustomer: double.parse(avgOrdersPerCustomer.toStringAsFixed(1)),
      averageLifetimeValue: double.parse(avgLifetimeValue.toStringAsFixed(3)),
    );
  }
}

// Helper classes for aggregation
class _OrderData {
  final String orderId;
  final om.OrderStatus status;
  final DateTime createdAt;
  final String userId;
  final double subtotal;
  final List<_OrderItemData> items;

  _OrderData({
    required this.orderId,
    required this.status,
    required this.createdAt,
    required this.userId,
    required this.subtotal,
    required this.items,
  });
}

class _OrderItemData {
  final String productId;
  final String name;
  final double price;
  final int qty;

  _OrderItemData({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
  });
}

class _ProductStats {
  final int quantitySold;
  final double revenue;
  final int orderCount;

  _ProductStats({
    this.quantitySold = 0,
    this.revenue = 0,
    this.orderCount = 0,
  });
}

class _CategoryStats {
  final int quantitySold;
  final double revenue;
  final Set<String> productIds;

  _CategoryStats({
    this.quantitySold = 0,
    this.revenue = 0,
    Set<String>? productIds,
  }) : productIds = productIds ?? {};
}

class _HourStats {
  final int orderCount;
  final double revenue;

  _HourStats({this.orderCount = 0, this.revenue = 0});
}

class _DayStats {
  final DateTime date;
  final double revenue;
  final int orderCount;

  _DayStats({
    required this.date,
    this.revenue = 0,
    this.orderCount = 0,
  });
}

/// Riverpod provider for analytics service
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final ids = ref.watch(effectiveIdsProvider);
  if (ids == null) {
    throw StateError('Missing merchant/branch IDs');
  }
  return AnalyticsService(
    merchantId: ids.merchantId,
    branchId: ids.branchId,
  );
});

/// Provider for analytics dashboard with date range
final analyticsDashboardProvider = FutureProvider.family<AnalyticsDashboard, DateRange>(
  (ref, dateRange) async {
    final service = ref.watch(analyticsServiceProvider);
    return service.computeAnalytics(dateRange: dateRange);
  },
);
