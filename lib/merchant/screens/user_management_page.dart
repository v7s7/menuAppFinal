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
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Staff Member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create a new staff account. They will use this email and password to log in.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'staff@example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
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
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Minimum 6 characters',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Staff will use this email and password to log in to the merchant portal.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              final password = passwordController.text.trim();

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

              if (password.isEmpty || password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters')),
                );
                return;
              }

              Navigator.pop(context);
              _addStaffUser(context, ref, email, name, password);
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
    String password,
  ) async {
    final roleService = ref.read(roleServiceProvider);
    if (roleService == null) return;

    // Save current user credentials to re-authenticate after creating staff
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Creating staff account...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Store current user's email for re-authentication
      final currentUserEmail = currentUser.email;

      // Create the new staff user account
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUserId = credential.user!.uid;

      // Update display name for the new user
      await credential.user!.updateDisplayName(displayName);

      // Create the role document with the actual Firebase UID
      await roleService.setUserRole(
        userId: newUserId,
        role: UserRole.staff,
        email: email,
        displayName: displayName,
        createdBy: currentUser.uid,
      );

      // Sign out the new user and back in as admin
      await FirebaseAuth.instance.signOut();

      // Note: Admin will need to sign in again manually
      // This is a limitation of the client-side approach

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Staff Added Successfully!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$displayName has been added as staff.'),
                const SizedBox(height: 12),
                const Text('Login credentials:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Email: $email'),
                Text('Password: $password'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'You have been signed out and need to log in again as admin. '
                        'Please save the staff credentials before closing this dialog.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate back to login screen
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('OK, Log In Again'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add staff: ${e.toString()}'),
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
