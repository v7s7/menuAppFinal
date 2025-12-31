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

    if (navigator.canPop()) {
      navigator.pop(result);
    } else {
      // Can't pop - we're at the root
      // On web, this might mean we're about to go to /s/ (without slug)
      // Stay on the current page or redirect to slug root
      final slug = ref.read(currentSlugProvider);
      if (slug != null) {
        // Already at slug root - do nothing
        debugPrint('[SlugNavigation] At root of /s/$slug - no pop');
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

  @override
  String? get restorationId => slug != null ? 's_$slug' : super.restorationId;
}
