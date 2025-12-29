import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/role_service.dart';

/// Widget that shows/hides children based on admin permission
class AdminOnly extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const AdminOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    if (isAdmin) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that shows/hides children based on menu management permission
class MenuManagerOnly extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const MenuManagerOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canManageMenuProvider);

    if (canManage) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that shows content only if user has analytics access
class AnalyticsOnly extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const AnalyticsOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canView = ref.watch(canViewAnalyticsProvider);

    if (canView) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that shows "Access Denied" message for unauthorized users
class AccessDeniedPage extends StatelessWidget {
  final String? message;

  const AccessDeniedPage({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                message ?? 'You do not have permission to access this page.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please contact an administrator if you need access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget wrapper that shows AccessDeniedPage if user doesn't have permission
class RequireAdmin extends ConsumerWidget {
  final Widget child;

  const RequireAdmin({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(currentUserRoleProvider);

    return roleAsync.when(
      data: (roleData) {
        if (roleData?.isAdmin ?? false) {
          return child;
        }
        return const AccessDeniedPage(
          message: 'This page is only accessible to administrators.',
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const AccessDeniedPage(
        message: 'Error loading permissions.',
      ),
    );
  }
}
