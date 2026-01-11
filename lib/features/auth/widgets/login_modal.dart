import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/auth/auth_service.dart';

Future<void> showLoginModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _LoginSheet(),
  );
}

class _LoginSheet extends ConsumerStatefulWidget {
  const _LoginSheet();

  @override
  ConsumerState<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<_LoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String _countryCode = '+973';

  final _countries = const ['+973', '+966', '+965', '+968', '+974', '+971'];

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _phoneE164 => '$_countryCode${_phoneController.text.trim()}';

  Future<void> _handleAuth({required bool signup}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final authService = ref.read(authServiceProvider);
    try {
      if (signup) {
        await authService.signUpWithPhone(
          phoneE164: _phoneE164,
          password: _passwordController.text.trim(),
        );
      } else {
        await authService.loginWithPhone(
          phoneE164: _phoneE164,
          password: _passwordController.text.trim(),
        );
      }

      // Give Firebase auth state a moment to propagate
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        Navigator.of(context).pop();
        // Show welcome message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(signup ? '✓ Welcome! Your account has been created.' : '✓ Welcome back!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = _mapAuthError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Account not found. Please sign up.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'Account already exists. Try login instead.';
      case 'invalid-email':
      case 'invalid-credential':
        return 'Invalid credentials. Please check your input.';
      default:
        return 'Login failed: ${e.message ?? e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 640;
    final content = Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Login or Sign up',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                DropdownButton<String>(
                  value: _countryCode,
                  onChanged: _loading
                      ? null
                      : (v) {
                          if (v != null) setState(() => _countryCode = v);
                        },
                  items: _countries
                      .map((c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: 'xxxxxxxx',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !_loading,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Required';
                      if (!RegExp(r'^\d+$').hasMatch(t)) return 'Digits only';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password (min 8)',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: _loading
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              enabled: !_loading,
              validator: (v) {
                if (v == null || v.length < 8) return 'Min 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _handleAuth(signup: false),
                    child: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _handleAuth(signup: true),
                    child: const Text('Sign up'),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );

    if (isWide) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: content,
        ),
      );
    }

    return content;
  }
}
