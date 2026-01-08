import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/branding/branding_providers.dart';
import '../../core/services/role_service.dart';
import '../../core/widgets/permission_gate.dart';
import 'user_management_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _whatsappNumberController = TextEditingController();
  bool _whatsappEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _whatsappNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final merchantId = ref.read(merchantIdProvider);
      final branchId = ref.read(branchIdProvider);

      final notificationsDoc = await FirebaseFirestore.instance
          .doc('merchants/$merchantId/branches/$branchId/config/notifications')
          .get();

      if (mounted) {
        setState(() {
          if (notificationsDoc.exists) {
            final data = notificationsDoc.data();
            _whatsappEnabled = data?['whatsappEnabled'] ?? false;
            _whatsappNumberController.text = data?['whatsappNumber'] ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load settings: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  bool _validateE164(String number) {
    // E.164 format: +[1-9][0-9]{7,14}
    final regex = RegExp(r'^\+[1-9]\d{7,14}$');
    return regex.hasMatch(number);
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final merchantId = ref.read(merchantIdProvider);
      final branchId = ref.read(branchIdProvider);
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Validate WhatsApp number if enabled
      final whatsappNumber = _whatsappNumberController.text.trim();
      if (_whatsappEnabled && !_validateE164(whatsappNumber)) {
        setState(() {
          _errorMessage =
              'Invalid WhatsApp number. Use E.164 format (e.g., +973XXXXXXXX)';
          _isSaving = false;
        });
        return;
      }

      await FirebaseFirestore.instance
          .doc('merchants/$merchantId/branches/$branchId/config/notifications')
          .set({
        'whatsappEnabled': _whatsappEnabled,
        'whatsappNumber': _whatsappEnabled ? whatsappNumber : '',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      if (mounted) {
        setState(() {
          _successMessage = 'WhatsApp notification settings saved successfully!';
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save settings: ${e.toString()}';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: theme.colorScheme.primaryContainer,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.primaryContainer,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // WhatsApp Notifications Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: theme.colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'WhatsApp Notifications',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Receive WhatsApp messages for new orders and cancellations',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Divider(height: 32),

                        // Enable/Disable toggle
                        SwitchListTile(
                          value: _whatsappEnabled,
                          onChanged: (value) {
                            setState(() {
                              _whatsappEnabled = value;
                            });
                          },
                          title: const Text('Enable WhatsApp Notifications'),
                          subtitle: Text(
                            _whatsappEnabled
                                ? 'You will receive WhatsApp messages for orders'
                                : 'WhatsApp notifications are disabled',
                          ),
                          secondary: Icon(
                            _whatsappEnabled
                                ? Icons.notifications_active
                                : Icons.notifications_off,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // WhatsApp number input
                        TextField(
                          controller: _whatsappNumberController,
                          decoration: InputDecoration(
                            labelText: 'WhatsApp Number',
                            hintText: '+973XXXXXXXX',
                            prefixIcon: const Icon(Icons.phone),
                            border: const OutlineInputBorder(),
                            helperText:
                                'E.164 format with country code (e.g., +973 for Bahrain)',
                            enabled: _whatsappEnabled,
                          ),
                          keyboardType: TextInputType.phone,
                        ),

                        const SizedBox(height: 24),

                        // Info box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'What you\'ll receive:',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '• Instant WhatsApp messages when new orders arrive\n'
                                      '• Notifications when orders are cancelled\n'
                                      '• Order details including items, table, and customer info',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Note about Twilio configuration
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            border: Border.all(color: Colors.blue.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.cloud_outlined,
                                size: 20,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Messages are sent via Cloudflare Worker using Twilio WhatsApp API. Configure your Worker with Twilio credentials to enable sending.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // User Management Section (Admin Only)
                AdminOnly(
                  child: Column(
                    children: [
                      Card(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const UserManagementPage(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.group_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Team Members',
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Manage staff access and permissions',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Current User Role Display
                Consumer(
                  builder: (context, ref, child) {
                    final roleData = ref.watch(currentUserRoleProvider).value;
                    if (roleData == null) return const SizedBox.shrink();

                    return Column(
                      children: [
                        Card(
                          color: roleData.isAdmin
                              ? Colors.purple.shade50
                              : Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  roleData.isAdmin
                                      ? Icons.admin_panel_settings
                                      : Icons.badge_outlined,
                                  color: roleData.isAdmin
                                      ? Colors.purple
                                      : Colors.blue,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your Role: ${roleData.role.displayName}',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (roleData.email.isNotEmpty)
                                        Text(
                                          roleData.email,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),

                // Error message
                if (_errorMessage != null)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Success message
                if (_successMessage != null)
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Save button
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
