import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

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
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  String _phoneE164 = '';
  bool _isSignup = false;
  bool _phoneValid = false;
  bool _passwordValid = false;
  bool _confirmPasswordValid = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateFields() {
    setState(() {
      _phoneValid = _phoneE164.isNotEmpty && _phoneE164.length >= 10;
      _passwordValid = _passwordController.text.trim().length >= 8;

      if (_isSignup) {
        _confirmPasswordValid =
            _confirmPasswordController.text.trim().length >= 8 &&
            _confirmPasswordController.text.trim() == _passwordController.text.trim();
      } else {
        _confirmPasswordValid = true; // Not needed for login
      }
    });
  }

  bool get _isFormValid => _phoneValid && _passwordValid && _confirmPasswordValid;

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all fields correctly'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check password match in signup mode
    if (_isSignup && _passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Passwords do not match'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final authService = ref.read(authServiceProvider);
    try {
      if (_isSignup) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSignup
                ? '✓ Welcome! Your account has been created.'
                : '✓ Welcome back!',
            ),
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
        return 'Authentication failed: ${e.message ?? e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final secondaryColor = theme.colorScheme.secondary;

    // Button color: grey when invalid, green when valid
    final buttonColor = _isFormValid && !_loading
        ? Colors.green.shade600
        : Colors.grey.shade400;

    final buttonTextColor = _isFormValid && !_loading
        ? Colors.white
        : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 24,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isSignup ? 'Create Account' : 'Welcome Back',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _loading ? null : () => Navigator.of(context).pop(),
                        color: onSurface.withOpacity(0.6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignup
                        ? 'Sign up to track orders, save addresses & earn rewards'
                        : 'Login to access your orders, addresses & saved items',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Phone number field
                  IntlPhoneField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(color: secondaryColor),
                      hintText: '12345678',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: onSurface.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _phoneValid
                            ? Colors.green.shade400
                            : onSurface.withOpacity(0.3),
                          width: _phoneValid ? 2 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: primaryColor.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixIcon: _phoneValid
                          ? Icon(Icons.check_circle, color: Colors.green.shade600, size: 20)
                          : null,
                    ),
                    initialCountryCode: 'BH',
                    dropdownIconPosition: IconPosition.trailing,
                    enabled: !_loading,
                    onChanged: (phone) {
                      _phoneE164 = phone.completeNumber;
                      _validateFields();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: secondaryColor),
                      hintText: _isSignup ? 'Min 8 characters' : 'Enter your password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: onSurface.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _passwordValid
                            ? Colors.green.shade400
                            : onSurface.withOpacity(0.3),
                          width: _passwordValid ? 2 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: primaryColor.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_passwordValid)
                            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                          if (_passwordValid) const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            ),
                            onPressed: _loading
                                ? null
                                : () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ],
                      ),
                    ),
                    obscureText: _obscurePassword,
                    enabled: !_loading,
                    onChanged: (_) => _validateFields(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8) return 'Password must be at least 8 characters';
                      return null;
                    },
                  ),

                  // Confirm Password field (only for signup)
                  if (_isSignup) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: TextStyle(color: secondaryColor),
                        hintText: 'Re-enter your password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: onSurface.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _confirmPasswordValid
                              ? Colors.green.shade400
                              : onSurface.withOpacity(0.3),
                            width: _confirmPasswordValid ? 2 : 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                        ),
                        filled: true,
                        fillColor: primaryColor.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_confirmPasswordValid && _confirmPasswordController.text.isNotEmpty)
                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                            if (_confirmPasswordValid && _confirmPasswordController.text.isNotEmpty)
                              const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              ),
                              onPressed: _loading
                                  ? null
                                  : () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ],
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      enabled: !_loading,
                      onChanged: (_) => _validateFields(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please confirm your password';
                        if (v != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action buttons row
                  Row(
                    children: [
                      // Cancel button
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _loading ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: onSurface.withOpacity(0.8),
                              side: BorderSide(color: onSurface.withOpacity(0.3), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Submit button
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (_loading || !_isFormValid) ? null : _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: buttonTextColor,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                              elevation: _isFormValid ? 2 : 0,
                              shadowColor: _isFormValid ? Colors.green.shade200 : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isFormValid)
                                        const Icon(Icons.check_circle_outline, size: 20),
                                      if (_isFormValid) const SizedBox(width: 8),
                                      Text(
                                        _isSignup ? 'Sign Up' : 'Login',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Toggle between login and signup
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignup ? 'Already have an account?' : "Don't have an account?",
                        style: TextStyle(
                          color: onSurface.withOpacity(0.7),
                        ),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _isSignup = !_isSignup;
                                  _confirmPasswordController.clear();
                                  _validateFields();
                                }),
                        child: Text(
                          _isSignup ? 'Login' : 'Sign Up',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
