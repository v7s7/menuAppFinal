/// Analytics data models for merchant insights

/// Date range filter for analytics queries
enum DateRange {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  custom;

  String get label {
    switch (this) {
      case DateRange.today:
        return 'Today';
      case DateRange.yesterday:
        return 'Yesterday';
      case DateRange.last7Days:
        return 'Last 7 Days';
      case DateRange.last30Days:
        return 'Last 30 Days';
      case DateRange.thisMonth:
        return 'This Month';
      case DateRange.lastMonth:
        return 'Last Month';
      case DateRange.custom:
        return 'Custom Range';
    }
  }

  /// Get start and end dates for the range
  ({DateTime start, DateTime end}) getDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case DateRange.today:
        return (start: today, end: now);
      case DateRange.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return (
          start: yesterday,
          end: today.subtract(const Duration(milliseconds: 1))
        );
      case DateRange.last7Days:
        return (start: today.subtract(const Duration(days: 6)), end: now);
      case DateRange.last30Days:
        return (start: today.subtract(const Duration(days: 29)), end: now);
      case DateRange.thisMonth:
        final firstDay = DateTime(now.year, now.month, 1);
        return (start: firstDay, end: now);
      case DateRange.lastMonth:
        final firstDayThisMonth = DateTime(now.year, now.month, 1);
        final firstDayLastMonth =
            DateTime(now.year, now.month - 1, 1);
        return (
          start: firstDayLastMonth,
          end: firstDayThisMonth.subtract(const Duration(milliseconds: 1))
        );
      case DateRange.custom:
        return (start: today, end: now);
    }
  }
}

/// Sales analytics summary
class SalesAnalytics {
  final double totalRevenue;
  final int totalOrders;
  final int totalItems;
  final double averageOrderValue;
  final int completedOrders;
  final int cancelledOrders;
  final double completionRate; // percentage

  const SalesAnalytics({
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalItems,
    required this.averageOrderValue,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.completionRate,
  });

  factory SalesAnalytics.empty() => const SalesAnalytics(
        totalRevenue: 0,
        totalOrders: 0,
        totalItems: 0,
        averageOrderValue: 0,
        completedOrders: 0,
        cancelledOrders: 0,
        completionRate: 0,
      );
}

/// Product performance metrics
class ProductPerformance {
  final String productId;
  final String productName;
  final int quantitySold;
  final double revenue;
  final int orderCount; // number of orders containing this product
  final double averageQuantityPerOrder;

  const ProductPerformance({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
    required this.orderCount,
    required this.averageQuantityPerOrder,
  });
}

/// Category performance metrics
class CategoryPerformance {
  final String categoryId;
  final String categoryName;
  final int quantitySold;
  final double revenue;
  final int productCount; // unique products in this category
  final double revenueShare; // percentage of total revenue

  const CategoryPerformance({
    required this.categoryId,
    required this.categoryName,
    required this.quantitySold,
    required this.revenue,
    required this.productCount,
    required this.revenueShare,
  });
}

/// Hourly distribution data
class HourlyDistribution {
  final int hour; // 0-23
  final int orderCount;
  final double revenue;

  const HourlyDistribution({
    required this.hour,
    required this.orderCount,
    required this.revenue,
  });
}

/// Daily trend data point
class DailyTrend {
  final DateTime date;
  final double revenue;
  final int orderCount;

  const DailyTrend({
    required this.date,
    required this.revenue,
    required this.orderCount,
  });
}

/// Customer insights
class CustomerInsights {
  final int totalCustomers;
  final int newCustomers;
  final int returningCustomers;
  final double customerRetentionRate; // percentage
  final double averageOrdersPerCustomer;
  final double averageLifetimeValue;

  const CustomerInsights({
    required this.totalCustomers,
    required this.newCustomers,
    required this.returningCustomers,
    required this.customerRetentionRate,
    required this.averageOrdersPerCustomer,
    required this.averageLifetimeValue,
  });

  factory CustomerInsights.empty() => const CustomerInsights(
        totalCustomers: 0,
        newCustomers: 0,
        returningCustomers: 0,
        customerRetentionRate: 0,
        averageOrdersPerCustomer: 0,
        averageLifetimeValue: 0,
      );
}

/// Complete analytics dashboard data
class AnalyticsDashboard {
  final DateRange dateRange;
  final DateTime startDate;
  final DateTime endDate;

  // Sales metrics
  final SalesAnalytics sales;

  // Product insights
  final List<ProductPerformance> topProducts;
  final List<ProductPerformance> slowMovingProducts;

  // Category breakdown
  final List<CategoryPerformance> categoryPerformance;

  // Time-based patterns
  final List<HourlyDistribution> hourlyDistribution;
  final List<DailyTrend> dailyTrends;

  // Customer data
  final CustomerInsights customerInsights;

  const AnalyticsDashboard({
    required this.dateRange,
    required this.startDate,
    required this.endDate,
    required this.sales,
    required this.topProducts,
    required this.slowMovingProducts,
    required this.categoryPerformance,
    required this.hourlyDistribution,
    required this.dailyTrends,
    required this.customerInsights,
  });

  factory AnalyticsDashboard.empty(DateRange range) {
    final dates = range.getDates();
    return AnalyticsDashboard(
      dateRange: range,
      startDate: dates.start,
      endDate: dates.end,
      sales: SalesAnalytics.empty(),
      topProducts: const [],
      slowMovingProducts: const [],
      categoryPerformance: const [],
      hourlyDistribution: const [],
      dailyTrends: const [],
      customerInsights: CustomerInsights.empty(),
    );
  }
}
