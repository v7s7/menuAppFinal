import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/models/user_role.dart';
import '../../core/services/role_service.dart';
import '../../core/widgets/permission_gate.dart';
import '../../core/branding/branding_providers.dart';
import '../../firebase_options.dart';

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

  // Track failed password attempts
  static int _failedPasswordAttempts = 0;
  static const int _maxPasswordAttempts = 3;

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
    final adminPasswordController = TextEditingController();

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
                  labelText: 'Staff Email',
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
                  labelText: 'Staff Password',
                  hintText: 'Minimum 6 characters',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Please confirm your admin password to create staff account',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adminPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Your Admin Password',
                  hintText: 'Confirm your password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.admin_panel_settings),
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
                        'Staff will use their email and password to log in to the merchant portal.',
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
              final adminPassword = adminPasswordController.text.trim();

              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter staff email')),
                );
                return;
              }

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter staff name')),
                );
                return;
              }

              if (password.isEmpty || password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Staff password must be at least 6 characters')),
                );
                return;
              }

              if (adminPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please confirm your admin password')),
                );
                return;
              }

              Navigator.pop(context);
              _addStaffUser(context, ref, email, name, password, adminPassword);
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
    String adminPassword,
  ) async {
    final roleService = ref.read(roleServiceProvider);
    if (roleService == null) return;

    // Save current user credentials to re-authenticate after creating staff
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final adminEmail = currentUser.email;
    if (adminEmail == null) return;

    final adminUid = currentUser.uid;

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
                    Text('Verifying admin password...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // STEP 0: Verify admin password FIRST before creating staff account
      try {
        // Create a temporary credential to verify the admin's password
        final credential = EmailAuthProvider.credential(
          email: adminEmail,
          password: adminPassword,
        );

        // Try to re-authenticate the current user
        await currentUser.reauthenticateWithCredential(credential);

        // Password is correct! Reset failed attempts counter
        _failedPasswordAttempts = 0;

        print('[UserManagement] ✓ Admin password verified successfully');
      } on FirebaseAuthException catch (e) {
        // Password verification failed
        _failedPasswordAttempts++;

        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
        }

        print('[UserManagement] ❌ Admin password verification failed (attempt $_failedPasswordAttempts/$_maxPasswordAttempts)');

        // Check if max attempts reached
        if (_failedPasswordAttempts >= _maxPasswordAttempts) {
          // Force logout after 3 failed attempts
          print('[UserManagement] ⚠️ Max password attempts reached - forcing logout');

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Too many incorrect password attempts. Logging out for security.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }

          // Wait a moment for the message to show, then logout
          await Future.delayed(const Duration(seconds: 2));
          await FirebaseAuth.instance.signOut();
          return;
        }

        // Show error and allow retry
        if (context.mounted) {
          final attemptsLeft = _maxPasswordAttempts - _failedPasswordAttempts;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Incorrect admin password. $attemptsLeft attempt${attemptsLeft == 1 ? "" : "s"} remaining.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Update loading dialog message
      if (context.mounted) {
        Navigator.pop(context); // Close verification dialog
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

      print('[UserManagement] 🔄 Starting staff creation for $email');

      // Step 1: Create staff user using SECONDARY auth instance
      // This prevents the admin from being signed out during staff creation
      // NOTE: We do NOT check context.mounted during creation - only when updating UI
      FirebaseApp? secondaryApp;
      String? newUserId;

      try {
        // Create a secondary Firebase app instance with unique name
        final secondaryAppName = 'staff_creation_${DateTime.now().millisecondsSinceEpoch}';
        print('[UserManagement] 🔄 Creating secondary Firebase app: $secondaryAppName');

        secondaryApp = await Firebase.initializeApp(
          name: secondaryAppName,
          options: DefaultFirebaseOptions.currentPlatform,
        );

        print('[UserManagement] ✓ Secondary Firebase app created');

        // Get auth instance for the secondary app
        print('[UserManagement] 🔄 Getting auth instance for secondary app');
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        print('[UserManagement] ✓ Got secondary auth instance');

        // Create staff user on secondary auth (doesn't affect primary admin session)
        print('[UserManagement] 🔄 Creating user with email: $email');
        final staffCredential = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('[UserManagement] ✓ User created with UID: ${staffCredential.user!.uid}');

        newUserId = staffCredential.user!.uid;

        // Update display name on the staff user
        print('[UserManagement] 🔄 Updating display name to: $displayName');
        await staffCredential.user!.updateDisplayName(displayName);
        print('[UserManagement] ✓ Display name updated');

        // Sign out from secondary auth immediately
        print('[UserManagement] 🔄 Signing out from secondary auth');
        await secondaryAuth.signOut();
        print('[UserManagement] ✓ Signed out from secondary auth');

        print('[UserManagement] ✓ Staff account created via secondary auth, admin session preserved');
      } finally {
        // Always clean up secondary app to prevent leaks
        if (secondaryApp != null) {
          try {
            print('[UserManagement] 🔄 Deleting secondary app');
            await secondaryApp.delete();
            print('[UserManagement] ✓ Secondary app deleted');
          } catch (e) {
            print('[UserManagement] ⚠️ Failed to delete secondary app: $e');
          }
        }
      }

      // Verify we got the user ID
      if (newUserId == null) {
        throw Exception('Failed to create staff user - no UID returned');
      }

      // Step 2: Create the role document using PRIMARY Firestore instance (as admin)
      // The admin is still logged in, so this has proper permissions
      print('[UserManagement] 🔄 Creating role document for UID: $newUserId');
      await roleService.setUserRole(
        userId: newUserId,
        role: UserRole.staff,
        email: email,
        displayName: displayName,
        createdBy: adminUid,
      );
      print('[UserManagement] ✓ Role document created');

      // Wait for Firestore propagation to prevent "No access" on first login
      print('[UserManagement] 🔄 Waiting for Firestore propagation (1500ms)...');
      await Future.delayed(const Duration(milliseconds: 1500));
      print('[UserManagement] ✓ Propagation wait complete');

      if (context.mounted) {
        print('[UserManagement] ✓ Closing loading dialog');
        Navigator.pop(context); // Close loading dialog

        print('[UserManagement] ✓ Staff creation complete! Showing success message');
        // Show success message - admin is still logged in!
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Staff member "$displayName" added successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Show credentials dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Staff Added Successfully!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$displayName has been added as staff.'),
                const SizedBox(height: 16),
                const Text('Login credentials:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.email, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(email, style: const TextStyle(fontFamily: 'monospace'))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.lock, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(password, style: const TextStyle(fontFamily: 'monospace'))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Share these credentials with the staff member. They can now log in to the merchant portal.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        // Check if it's an authentication error for admin password
        String errorMessage = 'Failed to add staff: ${e.toString()}';
        if (e.toString().contains('wrong-password') ||
            e.toString().contains('invalid-credential')) {
          errorMessage = 'Invalid admin password. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _confirmRemoveUser(BuildContext context, WidgetRef ref, RoleData user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff Access?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove ${user.displayName.isNotEmpty ? user.displayName : user.email} from the team?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'What happens:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Staff loses access to this merchant portal\n'
                    '• Their login credentials remain active\n'
                    '• Same email can be re-added later',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
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
      // Use the actual Firebase UID from the RoleData object
      await roleService.removeUser(user.uid);

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
