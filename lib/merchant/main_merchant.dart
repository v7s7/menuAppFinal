// lib/merchant/main_merchant.dart — FIXED: Unified Firebase init (web + mobile) + Orders tab
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';

// Config / IDs
import '../core/config/app_config.dart';
import '../core/config/slug_routing.dart';
import '../core/branding/branding_providers.dart';
import '../core/services/order_notification_service.dart';
import '../core/services/cancelled_order_notification_service.dart';
import '../core/services/role_service.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/products_screen.dart';
import 'screens/orders_admin_page.dart';
import 'screens/settings_page.dart';
import '../features/analytics/screens/analytics_dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean URLs on the web (no '#')
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }

  // Initialize Firebase on all platforms with generated options.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: MerchantApp()));
}

class MerchantApp extends ConsumerStatefulWidget {
  const MerchantApp({super.key});
  @override
  ConsumerState<MerchantApp> createState() => _MerchantAppState();
}

class _MerchantAppState extends ConsumerState<MerchantApp> {
  bool _idsApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryApplyIds());
  }

  void _tryApplyIds() {
    final ids = ref.read(effectiveIdsProvider);
    if (ids != null && !_idsApplied) {
      // Apply merchant/branch to global providers once
      // (URL: ?m=<merchantId>&b=<branchId> or /s/<slug>)
      ref.read(merchantIdProvider.notifier).setId(ids.merchantId);
      ref.read(branchIdProvider.notifier).setId(ids.branchId);
      setState(() => _idsApplied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-apply when URL-derived IDs resolve
    ref.listen<MerchantBranch?>(effectiveIdsProvider, (prev, next) {
      if (next != null && !_idsApplied) _tryApplyIds();
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sweets – Merchant Console',
      theme: ThemeData(colorSchemeSeed: Colors.pink, useMaterial3: true),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) {
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snap) {
                final user = snap.data;

                // Require real sign-in for admin (don’t auto anon-sign-in here)
                if (user == null) return const LoginScreen();

                // Wait until merchant/branch IDs are known
                if (!_idsApplied) {
                  final cfg = ref.watch(appConfigProvider);
                  final hint = (cfg.merchantId != null && cfg.branchId != null)
                      ? 'Loading...'
                      : (cfg.slug != null
                          ? 'Resolving "${cfg.slug}"...'
                          : '⚠️ Open with:\n• /s/<slug>\n• ?m=<merchantId>&b=<branchId>');
                  return _NeedIdsPage(hint: hint);
                }

                final m = ref.read(merchantIdProvider);
                final b = ref.read(branchIdProvider);
                return _MerchantShell(merchantId: m, branchId: b);
              },
            );
          },
        );
      },
    );
  }
}

class _MerchantShell extends ConsumerStatefulWidget {
  final String merchantId;
  final String branchId;
  const _MerchantShell({required this.merchantId, required this.branchId});

  @override
  ConsumerState<_MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends ConsumerState<_MerchantShell> {
  int _i = 0;
  final _notificationService = OrderNotificationService();
  final _cancelledOrderService = CancelledOrderNotificationService();
  StreamSubscription<DocumentSnapshot>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _watchSettingsAndStartNotifications();
  }

  @override
  void dispose() {
    _notificationService.stopListening();
    _cancelledOrderService.stopListening();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  /// Start email notification services (ALWAYS active)
  void _watchSettingsAndStartNotifications() async {
    try {
      // Load merchant name
      final brandingDoc = await FirebaseFirestore.instance
          .doc('merchants/${widget.merchantId}/branches/${widget.branchId}/config/branding')
          .get();
      final merchantName = brandingDoc.data()?['title'] as String? ?? 'Your Store';

      // Start listening for new orders - ALWAYS active, sends to default email
      _notificationService.startListening(
        merchantId: widget.merchantId,
        branchId: widget.branchId,
        merchantName: merchantName,
      );

      // Start listening for cancelled orders - ALWAYS active, sends to default email
      _cancelledOrderService.startListening(
        merchantId: widget.merchantId,
        branchId: widget.branchId,
        merchantName: merchantName,
      );

      print('[MerchantShell] ✅ Email notifications ALWAYS active - sending to default email');
      print('[MerchantShell] ✅ Cancelled order notifications ALWAYS active');
    } catch (e) {
      print('[MerchantShell] ❌ Failed to start notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch user role to determine available tabs
    final roleAsync = ref.watch(currentUserRoleProvider);

    // Show loading screen while role is being fetched
    if (roleAsync.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    // If there's an error or no role, show access denied
    if (roleAsync.hasError || roleAsync.value == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No access to this merchant',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please ask the merchant admin to grant you access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final roleData = roleAsync.value!;
    final isAdmin = roleData.isAdmin;

    // Build pages and destinations based on role
    final pages = <Widget>[];
    final destinations = <NavigationDestination>[];

    if (isAdmin) {
      // Admin: Show Products tab
      pages.add(ProductsScreen(merchantId: widget.merchantId, branchId: widget.branchId));
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: 'Products',
      ));
    }

    // Both admin and staff: Show Orders tab
    pages.add(const OrdersAdminPage());

    if (isAdmin) {
      // Admin: Show Analytics tab
      pages.add(const AnalyticsDashboardPage());
    }

    // Ensure selected index is valid
    if (_i >= pages.length) {
      _i = 0;
    }

    // Determine AppBar title based on current tab and role
    String getTitle() {
      if (isAdmin) {
        if (_i == 0) return 'Products';
        if (_i == 1) return 'Orders';
        return 'Analytics';
      } else {
        return 'Orders';
      }
    }

    // Show AppBar only for admin on non-Analytics pages
    // Staff: OrdersAdminPage has its own AppBar, so don't show MerchantShell AppBar
    // Admin: Analytics page has its own AppBar, so don't show it there
    final showAppBar = isAdmin && _i != pages.length - 1;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              title: Text(getTitle()),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsPage(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: pages.isNotEmpty ? pages[_i] : const Center(child: Text('No access')),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('merchants/${widget.merchantId}/branches/${widget.branchId}/orders')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          final pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

          // Add Orders destination with badge
          final ordersDestination = NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(pendingCount.toString()),
              backgroundColor: Colors.red,
              textColor: Colors.white,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(pendingCount.toString()),
              backgroundColor: Colors.red,
              textColor: Colors.white,
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Orders',
          );

          // Build final destinations list
          final finalDestinations = List<NavigationDestination>.from(destinations);
          finalDestinations.add(ordersDestination);

          if (isAdmin) {
            // Add Analytics for admin
            finalDestinations.add(const NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Analytics',
            ));
          }

          // Only show NavigationBar if there are 2+ destinations
          // Staff with only Orders page doesn't need navigation
          if (finalDestinations.length < 2) {
            return const SizedBox.shrink();
          }

          return NavigationBar(
            selectedIndex: _i.clamp(0, finalDestinations.length - 1),
            onDestinationSelected: (v) => setState(() => _i = v),
            destinations: finalDestinations,
          );
        },
      ),
    );
  }
}

class _NeedIdsPage extends StatelessWidget {
  final String hint;
  const _NeedIdsPage({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(hint, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
