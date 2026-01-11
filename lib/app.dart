// lib/app.dart - CUSTOMER APP (URL PRESERVED)
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/branding/branding_providers.dart';
import 'core/branding/branding.dart';
import 'core/config/app_config.dart';
import 'core/config/slug_routing.dart';
import 'features/sweets/widgets/sweets_viewport.dart';
import 'features/cart/widgets/cart_sheet.dart';
import 'features/cart/state/cart_controller.dart'; // for live cart count
import 'features/orders/widgets/active_orders_sheet.dart';
import 'features/orders/data/active_orders_service.dart'
    show activeOrdersCountProvider, activeOrdersServiceProvider;

class SweetsApp extends ConsumerStatefulWidget {
  const SweetsApp({super.key});
  @override
  ConsumerState<SweetsApp> createState() => _SweetsAppState();
}

class _SweetsAppState extends ConsumerState<SweetsApp> {
  bool _idsApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryApplyIds());
  }

  void _tryApplyIds() {
    final ids = ref.read(effectiveIdsProvider);
    if (ids != null && !_idsApplied) {
      ref.read(merchantIdProvider.notifier).setId(ids.merchantId);
      ref.read(branchIdProvider.notifier).setId(ids.branchId);
      setState(() => _idsApplied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // react to ID changes
    ref.listen<MerchantBranch?>(effectiveIdsProvider, (prev, next) {
      if (next != null && !_idsApplied) _tryApplyIds();
    });

    final baseTheme = ref.watch(themeDataProvider);

    // branding (for title + colors)
    final branding = ref
        .watch(brandingProvider)
        .maybeWhen(
          data: (b) => b,
          orElse: () => const Branding(
            title: 'App',
            headerText: '',
            primaryHex: '#FFFFFF',
            secondaryHex: '#000000',
          ),
        );
    final primary = _hexToColor(branding.primaryHex); // BG color ONLY
    final secondary = _hexToColor(branding.secondaryHex); // TEXT color ONLY

    // status/nav icon color based on BG luminance
    final overlay = (primary.computeLuminance() > 0.5)
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    SystemChrome.setSystemUIOverlayStyle(
      overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    // global theme: solid background = primary, fonts = secondary, bar = transparent
    final theme = baseTheme.copyWith(
      scaffoldBackgroundColor: primary,
      textTheme: baseTheme.textTheme.apply(
        bodyColor: secondary,
        displayColor: secondary,
        decorationColor: secondary,
      ),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        bodyColor: secondary,
        displayColor: secondary,
        decorationColor: secondary,
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: secondary, // AppBar text/icons use secondary
        systemOverlayStyle: overlay,
      ),
    );

    return MaterialApp(
      title: branding.title,
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Preserve the original route name (e.g., /s/aziz-burgers)
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              _idsApplied ? const _CustomerScaffold() : const _WaitingOrError(),
        );
      },
    );
  }
}

// Stateful so we can hold a GlobalKey for the AppBar cart button
class _CustomerScaffold extends ConsumerStatefulWidget {
  const _CustomerScaffold();
  @override
  ConsumerState<_CustomerScaffold> createState() => _CustomerScaffoldState();
}

class _CustomerScaffoldState extends ConsumerState<_CustomerScaffold> {
  // Shared with SweetsViewport for fly-to-cart target
  final GlobalKey _cartActionKey = GlobalKey();

  bool _hadPersistedActiveOrdersAtLaunch = false;
  bool _autoOpenedActiveOrders = false;

  ProviderSubscription? _activeOrdersServiceSub;
  ProviderSubscription<int>? _activeOrdersCountSub;

  @override
  void initState() {
    super.initState();

    // Best-effort immediate check (works if prefs are already loaded).
    _hadPersistedActiveOrdersAtLaunch =
        ref.read(activeOrdersServiceProvider)?.getStoredOrderIds().isNotEmpty ??
        false;

    // Determine whether this session started with persisted active orders.
    // This gates the "auto-open" behavior to refresh/cold-start only.
    _activeOrdersServiceSub = ref.listenManual(activeOrdersServiceProvider, (
      prev,
      next,
    ) {
      if (prev == null && next != null) {
        _hadPersistedActiveOrdersAtLaunch = next.getStoredOrderIds().isNotEmpty;
      }
    }, fireImmediately: true);

    // Auto-open Active Orders sheet once after refresh/cold-start.
    _activeOrdersCountSub = ref.listenManual<int>(activeOrdersCountProvider, (
      prev,
      next,
    ) {
      if (_autoOpenedActiveOrders) return;
      if (!_hadPersistedActiveOrdersAtLaunch) return;
      if (next <= 0) return;

      _autoOpenedActiveOrders = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openActiveOrdersSheet(context);
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _activeOrdersServiceSub?.close();
    _activeOrdersCountSub?.close();
    super.dispose();
  }

  void _openCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CartSheet(),
    );
  }

  void _openActiveOrdersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const ActiveOrdersSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = ref
        .watch(brandingProvider)
        .maybeWhen(
          data: (x) => x,
          orElse: () => const Branding(
            title: 'App',
            headerText: '',
            primaryHex: '#FFFFFF',
            secondaryHex: '#000000',
          ),
        );

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final cartCount = ref.watch(
      cartControllerProvider.select((c) => c.totalCount),
    );
    final activeOrdersCount = ref.watch(activeOrdersCountProvider);

    // Debug: log active orders count
    if (activeOrdersCount > 0) {
      debugPrint('[CustomerScaffold] Active orders count: $activeOrdersCount');
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false, // hides back arrow
        title: Text(
          b.title,
          style: AppTheme.scriptTitle.copyWith(color: onSurface),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    OutlinedButton(
                      key: _cartActionKey, // key shared with SweetsViewport
                      style: OutlinedButton.styleFrom(
                        shape: const CircleBorder(),
                        side: BorderSide(color: onSurface),
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                        foregroundColor: onSurface, // icon color
                      ),
                      onPressed: () => _openCartSheet(context),
                      child: const Icon(Icons.shopping_bag_outlined, size: 20),
                    ),
                    if (cartCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: IgnorePointer(
                          ignoring: true, // allow taps to hit the button
                          child: _CartCountBadge(
                            count: cartCount,
                            onSurface: onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
                if (activeOrdersCount > 0) ...[
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: const CircleBorder(),
                          side: BorderSide(color: onSurface),
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          foregroundColor: onSurface,
                        ),
                        onPressed: () => _openActiveOrdersSheet(context),
                        child: const Icon(Icons.receipt_long, size: 20),
                      ),
                      Positioned(
                        right: -2,
                        top: -2,
                        child: IgnorePointer(
                          ignoring: true,
                          child: _CartCountBadge(
                            count: activeOrdersCount,
                            onSurface: onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      body: SweetsViewport(cartBadgeKey: _cartActionKey),
    );
  }
}

class _WaitingOrError extends ConsumerWidget {
  const _WaitingOrError();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appConfigProvider);
    final async = ref.watch(slugLookupProvider);

    String message;
    if (cfg.merchantId != null && cfg.branchId != null) {
      message = 'Loading menu...';
    } else if (cfg.slug != null && cfg.slug!.isNotEmpty) {
      message = async.when(
        data: (mb) => mb == null
            ? '❌ Slug "${cfg.slug}" not found.\n\nAsk the merchant for the correct link.'
            : 'Loading menu...',
        loading: () => 'Resolving link...',
        error: (e, _) => '❌ Error: $e',
      );
    } else {
      message =
          '⚠️ No merchant specified.\n\nOpen with:\n'
          '• /s/<slug>\n'
          '• ?m=<merchantId>&b=<branchId>';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (async.isLoading)
                const CircularProgressIndicator()
              else
                const Icon(
                  Icons.store_outlined,
                  size: 64,
                  color: Colors.black26,
                ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartCountBadge extends StatelessWidget {
  final int count;
  final Color onSurface;
  const _CartCountBadge({required this.count, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red, // Red background for clear visibility
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.red.shade700, width: 1.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white, // White text for contrast
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final s = hex.replaceAll('#', '').trim();
  final v = int.parse(s.length == 6 ? 'FF$s' : s, radix: 16);
  return Color(v);
}
