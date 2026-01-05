// lib/features/sweets/widgets/sweets_viewport.dart
import 'dart:math' as math;
import 'dart:ui' show ImageFilter; // For glass blur effect
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sweets/data/sweets_repo.dart'; // sweetsStreamProvider
import '../../sweets/data/sweet.dart';
import '../../sweets/state/sweets_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../cart/state/cart_controller.dart';
import 'sweet_image.dart';
import 'nutrition_panel.dart';
import 'category_bar.dart';
import '../../categories/data/categories_repo.dart'; // categoriesStreamProvider
import '../../categories/data/category.dart';

// branding (for logo + nutrition note)
import '../../../core/branding/branding_providers.dart';
import '../../../core/branding/branding.dart';

class SweetsViewport extends ConsumerStatefulWidget {
  final GlobalKey cartBadgeKey; // AppBar cart button key for fly animation end
  const SweetsViewport({super.key, required this.cartBadgeKey});

  @override
  ConsumerState<SweetsViewport> createState() => _SweetsViewportState();
}

class _SweetsViewportState extends ConsumerState<SweetsViewport>
    with TickerProviderStateMixin {
  static const int _kInitialPage = 10000;

  // Home layout: 15% | 70% | 15% peeks
  late final PageController _pc =
      PageController(viewportFraction: 0.7, initialPage: _kInitialPage);

  int _qty = 1;

  // Note (small pill opens a sheet)
  final _noteCtrl = TextEditingController();

  final GlobalKey _activeImageKey = GlobalKey(); // used by fly-to-cart
  OverlayEntry? _flyEntry;

  ProviderSubscription<AsyncValue<List<Sweet>>>? _sweetsSub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final async = ref.read(sweetsStreamProvider);
      final sweets = async.value;
      if (sweets != null && sweets.isNotEmpty) {
        _applyInitialIndex(sweets);
      }
    });

    _sweetsSub = ref.listenManual<AsyncValue<List<Sweet>>>(
      sweetsStreamProvider,
      (prev, next) {
        final prevLen =
            prev?.maybeWhen(data: (l) => l.length, orElse: () => null);
        final list = next.maybeWhen(data: (l) => l, orElse: () => null);
        if (list != null && list.isNotEmpty) {
          if (prevLen == null || prevLen != list.length) {
            _applyInitialIndex(list);
          }
        }
      },
    );
  }

  void _applyInitialIndex(List<Sweet> sweets) {
    final idx = (_kInitialPage % sweets.length).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sweetsControllerProvider.notifier).setIndex(idx);
      if (_pc.hasClients) {
        try {
          _pc.jumpToPage(_kInitialPage);
        } catch (_) {}
      }
      setState(() {
        _qty = 1;
        _noteCtrl.clear();
      });
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    _flyEntry?.remove();
    _sweetsSub?.close();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sweetsAsync = ref.watch(sweetsStreamProvider);
    final catsAsync = ref.watch(categoriesStreamProvider);

    // Branding (logo + nutrition note) — safe trims
    final Branding? branding = ref.watch(brandingProvider).maybeWhen(
      data: (b) => b,
      orElse: () => null,
    );
    final String? logoUrl = (() {
      final s = branding?.logoUrl?.trim();
      return (s != null && s.isNotEmpty) ? s : null;
    })();
    final String? nutritionNote = (() {
      final s = branding?.nutritionNote.trim();
      return (s != null && s.isNotEmpty) ? s : null;
    })();

    return sweetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error loading menu:\n$e',
          textAlign: TextAlign.center,
        ),
      ),
      data: (allSweets) {
        final onSurface = Theme.of(context).colorScheme.onSurface;
        final typography = Theme.of(context).textTheme;
        final String? secondaryFamily = typography.titleSmall?.fontFamily;
        final List<Category> cats = catsAsync.value ?? <Category>[];
        final selCat = ref.watch(selectedCategoryIdProvider);
        final selSub = ref.watch(selectedSubcategoryIdProvider);

        final filtered = _filterByCategory(allSweets, cats, selCat, selSub);

        if (filtered.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const CategoryBar(),
              if (nutritionNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    nutritionNote,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (typography.titleSmall ?? const TextStyle()).copyWith(
                      fontFamily: secondaryFamily,
                      fontSize: (typography.titleSmall?.fontSize ?? 14) + 1.5,
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withOpacity(0.78),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text('No products in this category.',
                  style: TextStyle(color: onSurface)),
            ],
          );
        }

        final state = ref.watch(sweetsControllerProvider);
        final safeIndex = state.index % filtered.length;
        if (safeIndex != state.index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(sweetsControllerProvider.notifier).setIndex(safeIndex);
            }
          });
        }
        final current = filtered[safeIndex];

        final total = (current.price * _qty);
        final size = MediaQuery.of(context).size;
        final surface = Theme.of(context).colorScheme.surface;

        final bool isFlying = _flyEntry != null;

        // ==================== LAYOUT TWEAK CONSTANTS ====================
        // Edit ONLY these to tune spacing/sizing safely (no overlaps possible).
        const double topSafePadding = 14; // extra space below status bar
        const double logoBoxSize = 90;

        // Safe gaps that prevent touching (logo ↔ product ↔ dots)
        const double logoToProductGap = 22;
        const double productInnerPadding = 16;
        const double productToDotsGap = 22;

        // Product stage sizing (ADAPTIVE: will never overflow available height)
        const double productMaxHeight = 460;
        const double productMinHeight = 260;

        // Carousel motion (smaller = less drift toward dots)
        const double carouselVerticalDrift = 10;

        // Dots / sections spacing
        const double dotsBottomGap = 12;
        const double categoryBottomGap = 14;
        const double nameBottomGap = 8;
        const double controlsBottomGap = 12;

        // Category glass style
        const double catGlassRadius = 14;
        const double catGlassBlur = 14;
        const double catGlassOpacity = 0.50;
        const double catGlassBorderOpacity = 0.08;
        const double catGlassBorderWidth = 0.35;
        const double catGlassPadH = 10;
        const double catGlassPadV = 6;

        // Controls sizing (smaller but still tap-safe)
        const double priceFontSize = 15;
        // ================================================================

        return DefaultTextStyle.merge(
          style:
              Theme.of(context).textTheme.bodyMedium!.copyWith(color: onSurface),
          child: IconTheme(
            data: IconThemeData(color: onSurface),
            child: Column(
              children: [
                // TOP STAGE (logo + product) inside Flexible
                Flexible(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ============ MAIN CONTENT (NO OVERLAP GUARANTEE) ============
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final topInset = MediaQuery.of(context).padding.top;
                          final headerTop = topInset + topSafePadding;

                          final hasLogo = logoUrl != null;

                          // Height already used by header/logo
                          final used = headerTop +
                              (hasLogo ? (logoBoxSize + logoToProductGap) : 0);

                          final availableForStage =
                              math.max(0.0, constraints.maxHeight - used);

                          // Stage height MUST NOT exceed available space
                          double stageH = math.min(productMaxHeight, availableForStage);
                          if (availableForStage >= productMinHeight) {
                            stageH = math.max(stageH, productMinHeight);
                          }
                          // If space is tight, stageH can shrink below productMinHeight safely.

                          final stageContentH = math.max(
                            0.0,
                            stageH - (productInnerPadding * 2),
                          );

                          return Column(
                            children: [
                              SizedBox(height: headerTop),

                              // SECTION 1: LOGO (if present)
                              if (logoUrl case final url?)
                                IgnorePointer(
                                  ignoring: true,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    opacity: state.isDetailOpen ? 0 : 1,
                                    child: _LogoCard(
                                      url: url,
                                      box: logoBoxSize,
                                      icon: 74,
                                      borderOpacity: 0.18,
                                      fillOpacity: 0.15,
                                    ),
                                  ),
                                ),

                              if (hasLogo) const SizedBox(height: logoToProductGap),

                              // SECTION 2: PRODUCT STAGE (CENTERED + VERTICAL-CLIPPED)
                              // This stage is the "protected box". Nothing above/below can cross it.
                              SizedBox(
                                height: stageH,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: productInnerPadding),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: size.width * 0.92,
                                      ),
                                      // Clip vertically so product can never paint into logo/dots area,
                                      // while still allowing horizontal peeks.
                                      child: _VerticalOnlyClip(
                                        child: _Carousel(
                                          controller: _pc,
                                          sweets: filtered,
                                          isDetailOpen: state.isDetailOpen,
                                          hostImageKey: _activeImageKey,
                                          onImageTap: () => ref
                                              .read(sweetsControllerProvider.notifier)
                                              .toggleDetail(),
                                          onIndexChanged: (i) {
                                            ref
                                                .read(sweetsControllerProvider.notifier)
                                                .setIndex((i % filtered.length).toInt());
                                            setState(() {
                                              _qty = 1;
                                              _noteCtrl.clear();
                                            });
                                          },
                                          maxItemHeight: stageContentH,
                                          verticalDrift: carouselVerticalDrift,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // ============ DETAIL OVERLAYS (OK to overlay within stage) ============
                      if (state.isDetailOpen)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: size.width * 0.5,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: surface),
                            ),
                          ),
                        ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: NutritionPanel(
                            sweet: current,
                            visible: state.isDetailOpen,
                            onClose: () => ref
                                .read(sweetsControllerProvider.notifier)
                                .closeDetail(),
                          ),
                        ),
                      ),

                      if (nutritionNote != null && nutritionNote.isNotEmpty)
                        Align(
                          alignment: const Alignment(0, 0.9),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 160),
                            opacity: state.isDetailOpen ? 1 : 0,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Text(
                                nutritionNote,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: onSurface.withOpacity(0.9),
                                          fontFamily: secondaryFamily,
                                          height: 1.25,
                                        ) ??
                                    TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: onSurface.withOpacity(0.9),
                                      fontFamily: secondaryFamily,
                                      height: 1.25,
                                    ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ==================== BOTTOM UI (NORMAL FLOW) ====================

                // GUARANTEED SAFE GAP: Product stage → Dots
                const SizedBox(height: productToDotsGap),

                if (filtered.length > 1) ...[
                  IgnorePointer(
                    ignoring: state.isDetailOpen,
                    child: AnimatedOpacity(
                      opacity: state.isDetailOpen ? 0 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: _DotsIndicator(
                        count: filtered.length,
                        active: safeIndex,
                        color: onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: dotsBottomGap),
                ],

                // iOS glass category bar (subtle, thin)
                IgnorePointer(
                  ignoring: state.isDetailOpen,
                  child: AnimatedOpacity(
                    opacity: state.isDetailOpen ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(catGlassRadius),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: catGlassBlur,
                              sigmaY: catGlassBlur,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: surface.withOpacity(catGlassOpacity),
                                borderRadius:
                                    BorderRadius.circular(catGlassRadius),
                                border: Border.all(
                                  color: onSurface.withOpacity(catGlassBorderOpacity),
                                  width: catGlassBorderWidth,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: catGlassPadH,
                                vertical: catGlassPadV,
                              ),
                              child: const CategoryBar(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: categoryBottomGap),

                // PRODUCT NAME
                IgnorePointer(
                  ignoring: state.isDetailOpen,
                  child: AnimatedOpacity(
                    opacity: state.isDetailOpen ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: a, child: c),
                      ),
                      child: Text(
                        current.name,
                        key: ValueKey(current.id),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: onSurface,
                              letterSpacing: 0.2,
                              height: 1.1,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: nameBottomGap),

                // PRICE + QTY + CART
                IgnorePointer(
                  ignoring: state.isDetailOpen,
                  child: AnimatedOpacity(
                    opacity: state.isDetailOpen ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          total.toStringAsFixed(3),
                          style: TextStyle(
                            color: onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: priceFontSize,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _QtyStepper(
                          onSurface: onSurface,
                          qty: _qty,
                          onDec: () =>
                              setState(() => _qty = (_qty > 1) ? _qty - 1 : 1),
                          onInc: () =>
                              setState(() => _qty = (_qty < 99) ? _qty + 1 : 99),
                        ),
                        const SizedBox(width: 6),
                        _AddIconButton(
                          onSurface: onSurface,
                          enabled: !isFlying,
                          onTap: () => _handleAddToCart(
                            current,
                            qty: _qty,
                            note: _noteCtrl.text.trim(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: controlsBottomGap),

                // ADD NOTE
                IgnorePointer(
                  ignoring: state.isDetailOpen,
                  child: AnimatedOpacity(
                    opacity: state.isDetailOpen ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Center(
                      child: _NotePill(
                        hasNote: _noteCtrl.text.trim().isNotEmpty,
                        onSurface: onSurface,
                        onTap: _openNoteSheet,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom + 8
                      : 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Sweet> _filterByCategory(
    List<Sweet> sweets,
    List<Category> cats,
    String? selCat,
    String? selSub,
  ) {
    if (selSub != null) {
      return sweets.where((s) => s.categoryId == selSub).toList();
    }
    if (selCat != null) {
      final childIds =
          cats.where((c) => (c.parentId ?? '') == selCat).map((c) => c.id);
      final allowed = <String>{selCat, ...childIds};
      return sweets
          .where((s) => s.categoryId != null && allowed.contains(s.categoryId))
          .toList();
    }
    return sweets;
  }

  Future<void> _openNoteSheet() async {
    final tmp = TextEditingController(text: _noteCtrl.text);
    final res = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + keyboardHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order note', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: onSurface.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: onSurface.withOpacity(0.12)),
                  ),
                  child: TextField(
                    controller: tmp,
                    autofocus: true,
                    textInputAction: TextInputAction.newline,
                    maxLines: 5,
                    minLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      hintText:
                          'Write special instructions (e.g., less sugar, extra sauce)…',
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, ''),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, tmp.text.trim()),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {
      if (res == null) return; // dismissed
      _noteCtrl.text = res;
    });
  }

  Future<void> _handleAddToCart(
    Sweet sweet, {
    required int qty,
    required String note,
  }) async {
    // Try addWithNote; fallback to add
    final cart = ref.read(cartControllerProvider.notifier);
    try {
      // ignore: avoid_dynamic_calls
      await (cart as dynamic)
          .addWithNote(sweet, qty: qty, note: note.isEmpty ? null : note);
    } catch (_) {
      cart.add(sweet, qty: qty);
    }

    // Clear note after adding to cart
    if (mounted) setState(() => _noteCtrl.clear());

    final overlay = Overlay.maybeOf(context);
    await Haptics.light();
    if (overlay == null || !mounted) return;

    // Get product image for animation
    final productImageUrl = sweet.imageUrl;

    final start = _centerOfKey(_activeImageKey);
    final end = _centerOfKey(widget.cartBadgeKey);
    if (start == null || end == null) return;

    _flyEntry?.remove();
    _flyEntry = null;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final curve =
        CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

    final tweenX = Tween<double>(begin: start.dx, end: end.dx);
    final tweenY = Tween<double>(begin: start.dy, end: end.dy - 8);
    final sizeTween = Tween<double>(begin: 64, end: 20);

    final entry = OverlayEntry(builder: (ctx) {
      final onSurface = Theme.of(ctx).colorScheme.onSurface;
      return AnimatedBuilder(
        animation: curve,
        builder: (ctx, _) {
          final x = tweenX.evaluate(curve);
          final y = tweenY.evaluate(curve) - 120 * _arc(curve.value);
          final s = sizeTween.evaluate(curve);
          return Positioned(
            left: x - s / 2,
            top: y - s / 2,
            child: IgnorePointer(
              child: Opacity(
                opacity: (1 - curve.value * 0.4),
                child: ClipOval(
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onSurface.withOpacity(0.12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: (productImageUrl?.isNotEmpty ?? false)
                        ? ClipOval(
                            child: Image.network(
                              productImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.shopping_bag_outlined),
                            ),
                          )
                        : const FittedBox(
                            fit: BoxFit.cover,
                            child: Icon(Icons.shopping_bag_outlined),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });

    overlay.insert(entry);
    _flyEntry = entry;

    controller.addStatusListener((st) {
      if (st == AnimationStatus.completed || st == AnimationStatus.dismissed) {
        if (entry.mounted) {
          try {
            entry.remove();
          } catch (_) {}
        }
        if (identical(_flyEntry, entry)) {
          _flyEntry = null;
        }
        controller.dispose();
        setState(() {});
      }
    });

    setState(() {});
    controller.forward();
  }

  double _arc(double t) => math.sin(t * math.pi);

  Offset? _centerOfKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos + box.size.center(Offset.zero);
  }
}

/* ---------- Vertical-only clip: clips top/bottom, keeps horizontal peeks ---------- */

class _VerticalOnlyClip extends StatelessWidget {
  final Widget child;
  const _VerticalOnlyClip({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: _VerticalOnlyClipper(),
      child: child,
    );
  }
}

class _VerticalOnlyClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    // Extend horizontally so peeks remain visible; clip only vertical bounds.
    return Rect.fromLTWH(-10000, 0, size.width + 20000, size.height);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

/* ---------- Isolated carousel (reduces rebuilds while scrolling) ---------- */

class _Carousel extends StatefulWidget {
  final PageController controller;
  final List<Sweet> sweets;
  final bool isDetailOpen;
  final VoidCallback onImageTap;
  final ValueChanged<int> onIndexChanged;
  final GlobalKey hostImageKey;

  // New: constrain item height + reduce drift so it never hits dots/logo visually.
  final double maxItemHeight;
  final double verticalDrift;

  const _Carousel({
    required this.controller,
    required this.sweets,
    required this.isDetailOpen,
    required this.onImageTap,
    required this.onIndexChanged,
    required this.hostImageKey,
    required this.maxItemHeight,
    required this.verticalDrift,
  });

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  static const int _kInitialPage = _SweetsViewportState._kInitialPage;
  double _page = _kInitialPage.toDouble();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant _Carousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      widget.controller.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final p = widget.controller.page;
    if (p != null && p != _page) {
      setState(() => _page = p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.controller,
      padEnds: true,
      clipBehavior: Clip.none,
      pageSnapping: true,
      physics: widget.isDetailOpen
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      onPageChanged: widget.onIndexChanged,
      itemBuilder: (ctx, i) {
        final sweet = widget.sweets[i % widget.sweets.length];
        return _buildPageItem(context, sweet, i);
      },
    );
  }

  Widget _buildPageItem(
    BuildContext context,
    Sweet sweet,
    int i,
  ) {
    final t = (_page - i).clamp(-1.0, 1.0);
    final scale = 1 - (0.18 * t.abs());
    final y = widget.verticalDrift * t.abs(); // reduced drift
    final rot = 0.02 * -t;

    final int activeHost = widget.controller.hasClients
        ? (widget.controller.page?.round() ?? _kInitialPage)
        : _kInitialPage;
    final bool isHost = (i == activeHost);

    return Transform.translate(
      offset: Offset(0, y),
      child: Transform.scale(
        scale: scale,
        child: Transform.rotate(
          angle: rot,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: widget.maxItemHeight,
              ),
              child: SweetImage(
                imageAsset: (sweet.imageAsset ?? ''),
                isActive: (_page - i).abs() < 0.5,
                isDetailOpen: widget.isDetailOpen,
                hostKey: isHost ? widget.hostImageKey : null,
                onTap: widget.onImageTap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- UI pieces ---------- */

class _NotePill extends StatelessWidget {
  final bool hasNote;
  final VoidCallback onTap;
  final Color onSurface;
  const _NotePill({
    required this.hasNote,
    required this.onTap,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final bg = hasNote ? onSurface.withOpacity(0.10) : Colors.transparent;
    final side = onSurface.withOpacity(hasNote ? 0.25 : 0.18);
    final fg = onSurface.withOpacity(0.95);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(40, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        side: BorderSide(color: side),
        backgroundColor: bg,
        shape: const StadiumBorder(),
        foregroundColor: fg,
      ),
      onPressed: onTap,
      icon: Icon(
        hasNote ? Icons.sticky_note_2 : Icons.note_add_outlined,
        size: 18,
      ),
      label: Text(hasNote ? 'Note added' : 'Add note'),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final Color onSurface;

  const _QtyStepper({
    required this.qty,
    required this.onDec,
    required this.onInc,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final bg = onSurface.withOpacity(0.10);
    final border = onSurface.withOpacity(0.12);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _step(
              icon: Icons.remove_rounded,
              onTap: onDec,
              onSurface: onSurface,
              semantics: 'Decrease quantity',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                qty.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: onSurface,
                ),
              ),
            ),
            _step(
              icon: Icons.add_rounded,
              onTap: onInc,
              onSurface: onSurface,
              semantics: 'Increase quantity',
            ),
          ],
        ),
      ),
    );
  }

  Widget _step({
    required IconData icon,
    required VoidCallback onTap,
    required Color onSurface,
    required String semantics,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7.0),
          child: Icon(icon, size: 18, color: onSurface),
        ),
      ),
    );
  }
}

class _AddIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color onSurface;
  final bool enabled;
  const _AddIconButton({
    required this.onTap,
    required this.onSurface,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add to cart',
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(color: onSurface, width: 1.5),
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          foregroundColor: onSurface,
        ),
        onPressed: enabled ? onTap : null,
        child: const Icon(Icons.shopping_bag_outlined, size: 20),
      ),
    );
  }
}

/// Instagram-like dots indicator (windowed for large lists)
class _DotsIndicator extends StatelessWidget {
  final int count;
  final int active;
  final Color color;

  const _DotsIndicator({
    required this.count,
    required this.active,
    required this.color,
  });

  static const int _kMaxDots = 12;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final visible = _visibleIndices(count, active, _kMaxDots);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < visible.length; i++)
          _dot(
            isActive: visible[i] == active,
            isEdgeTruncator: (i == 0 && visible.first > 0) ||
                (i == visible.length - 1 && visible.last < count - 1),
          ),
      ],
    );
  }

  Widget _dot({required bool isActive, required bool isEdgeTruncator}) {
    if (isEdgeTruncator) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: color.withOpacity(0.20),
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    final double size = isActive ? 8 : 6;
    final double opacity = isActive ? 0.95 : 0.35;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  List<int> _visibleIndices(int count, int active, int max) {
    if (count <= max) return List<int>.generate(count, (i) => i);
    final int half = (max / 2).floor();
    int start = active - half;
    int end = active + half;
    if (max.isEven) end -= 1;
    if (start < 0) {
      end += -start;
      start = 0;
    }
    if (end > count - 1) {
      start -= (end - (count - 1));
      end = count - 1;
    }
    if (start < 0) start = 0;
    final len = end - start + 1;
    if (len > max) end -= (len - max);
    return List<int>.generate(end - start + 1, (i) => start + i);
  }
}

/// Center logo card used on the home viewport.
class _LogoCard extends StatelessWidget {
  final String url;
  final double box; // outer square size
  final double icon; // image size inside
  final double borderOpacity;
  final double fillOpacity;
  const _LogoCard({
    required this.url,
    required this.box,
    required this.icon,
    required this.borderOpacity,
    required this.fillOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(fillOpacity),
        borderRadius: BorderRadius.circular(box * 0.23),
        border: Border.all(color: onSurface.withOpacity(borderOpacity)),
      ),
      child: Center(
        child: Image.network(
          url,
          width: icon,
          height: icon,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
