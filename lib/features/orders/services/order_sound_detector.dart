import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sound_alert_service.dart';
import '../data/order_models.dart' as om;

/// Detects new orders and plays sound alerts
class OrderSoundDetector {
  final SoundAlertService _soundService;
  final Ref _ref;

  // Track known order IDs to detect new ones
  final Set<String> _knownOrderIds = {};
  bool _isFirstLoad = true;

  OrderSoundDetector(this._soundService, this._ref);

  /// Process a list of orders and detect new ones
  Future<void> processOrders(List<dynamic> orders) async {
    // Skip the first load to avoid playing sounds for existing orders
    if (_isFirstLoad) {
      _knownOrderIds.clear();
      for (final order in orders) {
        if (order is Map<String, dynamic> && order.containsKey('id')) {
          _knownOrderIds.add(order['id'] as String);
        }
      }
      _isFirstLoad = false;
      if (kDebugMode) {
        debugPrint('[OrderSoundDetector] First load: ${_knownOrderIds.length} existing orders');
      }
      return;
    }

    // Check if sounds are enabled
    final isEnabled = _ref.read(soundAlertEnabledProvider);
    if (!isEnabled) return;

    // Detect new orders
    final List<String> newOrderIds = [];
    for (final order in orders) {
      if (order is Map<String, dynamic> && order.containsKey('id')) {
        final orderId = order['id'] as String;
        if (!_knownOrderIds.contains(orderId)) {
          newOrderIds.add(orderId);
          _knownOrderIds.add(orderId);

          // Check if it's a pending order (new order alert)
          final status = order.containsKey('status') ? order['status'] as String : 'pending';
          if (status == 'pending') {
            if (kDebugMode) {
              debugPrint('[OrderSoundDetector] New pending order detected: $orderId');
            }
            await _soundService.playNewOrderAlert();
          }
        }
      }
    }

    if (newOrderIds.isNotEmpty && kDebugMode) {
      debugPrint('[OrderSoundDetector] ${newOrderIds.length} new order(s) detected');
    }
  }

  /// Reset detector (useful when switching branches)
  void reset() {
    _knownOrderIds.clear();
    _isFirstLoad = true;
    if (kDebugMode) {
      debugPrint('[OrderSoundDetector] Reset detector');
    }
  }
}

/// Provider for order sound detector
final orderSoundDetectorProvider = Provider<OrderSoundDetector>((ref) {
  final soundService = ref.watch(soundAlertServiceProvider);
  return OrderSoundDetector(soundService, ref);
});
