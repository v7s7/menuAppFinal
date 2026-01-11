import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';

/// Maps a phone in E.164 format to a pseudo-email for Firebase Email/Password.
/// Example: +97312345678 -> phone_97312345678@sweets.app
String pseudoEmailFromPhone(String phoneE164) {
  final digits = phoneE164.replaceAll(RegExp(r'[^0-9]'), '');
  return 'phone_$digits@sweets.app';
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _fs;

  /// Stream of auth state changes (anonymous included)
  Stream<User?> get authState => _auth.authStateChanges();

  /// Sign up with phone+password using pseudo-email mapping.
  /// If current user is anonymous, link to preserve session/cart.
  Future<UserCredential> signUpWithPhone({
    required String phoneE164,
    required String password,
    String? displayName,
  }) async {
    final email = pseudoEmailFromPhone(phoneE164);
    final credential = EmailAuthProvider.credential(email: email, password: password);
    UserCredential userCred;

    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      // Link anonymous session to keep cart/session
      userCred = await _auth.currentUser!.linkWithCredential(credential);
    } else {
      userCred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    }

    await _ensureProfile(userCred.user!, phoneE164: phoneE164, displayName: displayName);
    return userCred;
  }

  /// Login with phone+password (pseudo-email mapping)
  Future<UserCredential> loginWithPhone({
    required String phoneE164,
    required String password,
  }) async {
    final email = pseudoEmailFromPhone(phoneE164);
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _ensureProfile(cred.user!, phoneE164: phoneE164);
    return cred;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Write user profile to users/{uid} if missing.
  Future<void> _ensureProfile(User user, {required String phoneE164, String? displayName}) async {
    final doc = _fs.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (snap.exists) return;

    final profile = UserProfile(
      uid: user.uid,
      phoneE164: phoneE164,
      displayName: displayName ?? user.displayName,
      createdAt: DateTime.now(),
    );

    await doc.set(profile.toMap());
  }
}

/// Providers
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Auth state (includes anonymous guest sessions)
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// True when user is logged in AND not anonymous
final isLoggedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(
    data: (user) => user != null && !user.isAnonymous,
    orElse: () => false,
  );
});

/// Current uid when logged in (non-anonymous), else null
final currentUidProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(
    data: (user) => (user != null && !user.isAnonymous) ? user.uid : null,
    orElse: () => null,
  );
});

/// Stream of user profile when logged in; null otherwise
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final auth = ref.watch(authStateProvider);

  return auth.maybeWhen(
    data: (user) {
      if (user == null || user.isAnonymous) {
        return Stream<UserProfile?>.value(null);
      }
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        return UserProfile.fromMap(snap.data()!, snap.id);
      });
    },
    orElse: () => const Stream<UserProfile?>.empty(),
  );
});

/// Convenience alias to read user profile as AsyncValue
final userProfileProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  return ref.watch(userProfileStreamProvider);
});
