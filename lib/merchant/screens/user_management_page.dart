import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/user_role.dart';
import '../../core/services/role_service.dart';
import '../../core/widgets/permission_gate.dart';
import '../../core/branding/branding_providers.dart';

/// User management page for admins to add/remove staff
class UserManagementPage extends ConsumerWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RequireAdmin(
      child: const _UserManagementContent(),
    );
  }
}

class _UserManagementContent extends ConsumerWidget {
  const _UserManagementContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleService = ref.watch(roleServiceProvider);
    final merchantId = ref.watch(merchantIdProvider);
    final branchId = ref.watch(branchIdProvider);

    if (roleService == null || merchantId == null || branchId == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Missing configuration')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Members'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
      body: StreamBuilder<List<RoleData>>(
        stream: roleService.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading users: ${snapshot.error}'),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No team members yet.\nTap "Add Staff" to invite someone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final user = users[index];
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.isAdmin
                      ? Colors.purple.shade100
                      : Colors.blue.shade100,
                  child: Icon(
                    user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: user.isAdmin ? Colors.purple : Colors.blue,
                  ),
                ),
                title: Text(user.displayName.isNotEmpty ? user.displayName : user.email),
                subtitle: Text(
                  '${user.role.displayName}${user.email.isNotEmpty ? " • ${user.email}" : ""}',
                ),
                trailing: user.role == UserRole.admin
                    ? const Chip(
                        label: Text('Admin'),
                        backgroundColor: Colors.purple,
                        labelStyle: TextStyle(color: Colors.white),
                      )
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                        tooltip: 'Remove access',
                        onPressed: () => _confirmRemoveUser(context, ref, user),
                      ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Staff Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the email and name of the person you want to add as staff.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'staff@example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'John Doe',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final email = emailController.text.trim();
              final name = nameController.text.trim();

              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an email')),
                );
                return;
              }

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              Navigator.pop(context);
              _addStaffUser(context, ref, email, name);
            },
            child: const Text('Add Staff'),
          ),
        ],
      ),
    );
  }

  Future<void> _addStaffUser(
    BuildContext context,
    WidgetRef ref,
    String email,
    String displayName,
  ) async {
    final roleService = ref.read(roleServiceProvider);
    if (roleService == null) return;

    try {
      // Create a temporary user ID based on email (will be replaced when user logs in)
      // In a real app, you might want to use Firebase Auth Admin SDK to create the user
      final userId = email.replaceAll('@', '_at_').replaceAll('.', '_');

      await roleService.setUserRole(
        userId: userId,
        role: UserRole.staff,
        email: email,
        displayName: displayName,
        createdBy: FirebaseAuth.instance.currentUser?.uid,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName added as staff. They can log in with $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add staff: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmRemoveUser(BuildContext context, WidgetRef ref, RoleData user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Access?'),
        content: Text(
          'Remove ${user.displayName.isNotEmpty ? user.displayName : user.email} from the team?\n\n'
          'They will no longer be able to access this merchant portal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _removeUser(context, ref, user);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeUser(BuildContext context, WidgetRef ref, RoleData user) async {
    final roleService = ref.read(roleServiceProvider);
    if (roleService == null) return;

    try {
      // Get user ID from email (reverse the temporary ID creation)
      final userId = user.email.replaceAll('@', '_at_').replaceAll('.', '_');
      await roleService.removeUser(userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} removed from team'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
