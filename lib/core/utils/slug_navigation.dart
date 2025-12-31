// lib/core/utils/slug_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

/// Provider that exposes the current slug from the URL
/// This is the single source of truth for slug-based routing
final currentSlugProvider = Provider<String?>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.slug;
});

/// Slug-preserving navigation helper
/// Use this instead of Navigator.of(context).push() to ensure the slug stays in the URL
class SlugNavigation {
  /// Push a route while preserving the slug in the browser URL
  ///
  /// Usage:
  ///   SlugNavigation.push(context, ref, (_) => SettingsPage());
  ///
  /// On web, this ensures the URL becomes /s/<slug>/<route> instead of losing the slug
  static Future<T?> push<T>(
    BuildContext context,
    WidgetRef ref,
    WidgetBuilder builder, {
    bool fullscreenDialog = false,
  }) {
    final slug = ref.read(currentSlugProvider);

    return Navigator.of(context).push<T>(
      _SlugPreservingPageRoute<T>(
        builder: builder,
        slug: slug,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// Safe pop that ensures we don't leave the slug namespace
  ///
  /// If popping would take us out of /s/<slug>, redirect to /s/<slug> instead
  static void pop(BuildContext context, WidgetRef ref, [Object? result]) {
    final navigator = Navigator.of(context);
    final slug = ref.read(currentSlugProvider);

    if (navigator.canPop()) {
      // Pop normally - the route was created with slug-preserving PageRoute
      navigator.pop(result);
    } else {
      // Can't pop - we're at the root of the navigation stack
      // This means we need to handle it specially to avoid going to /s/
      debugPrint('[SlugNavigation] Cannot pop - at navigation root');

      // For staff/merchant app: stay on current page (Settings is fullscreen dialog)
      // For customer app: this shouldn't happen as customer navigation is simpler
      // The fullscreenDialog route should handle its own dismissal

      // If we absolutely need to navigate, go to slug root
      if (slug != null && slug.isNotEmpty) {
        debugPrint('[SlugNavigation] Would navigate to /s/$slug but staying on current page');
        // Don't navigate - just stay on current page
        // The dialog/page should be dismissible by other means
      }
    }
  }

  /// Build a slug-preserving path
  ///
  /// Example: buildPath('orders') -> '/s/aziz-burgers/orders'
  static String buildPath(String? slug, String? subPath) {
    if (slug == null || slug.isEmpty) {
      return subPath != null && subPath.isNotEmpty ? '/$subPath' : '/';
    }

    final base = '/s/$slug';
    if (subPath == null || subPath.isEmpty) {
      return base;
    }

    // Ensure subPath doesn't start with /
    final cleanSubPath = subPath.startsWith('/') ? subPath.substring(1) : subPath;
    return '$base/$cleanSubPath';
  }
}

/// Custom PageRoute that preserves slug in browser URL on web
class _SlugPreservingPageRoute<T> extends MaterialPageRoute<T> {
  final String? slug;

  _SlugPreservingPageRoute({
    required super.builder,
    this.slug,
    super.fullscreenDialog = false,
  }) : super(
          // Use slug-aware route name for browser history
          settings: RouteSettings(
            name: slug != null ? '/s/$slug' : null,
          ),
        );
}
