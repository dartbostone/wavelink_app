import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/user_model.dart';

/// Wraps Firebase Authentication + the mirrored `users` collection.
///
/// Real authentication (Firebase Auth) is used, per the assignment's
/// preference for real auth over a mock. All methods throw a plain
/// [String] message on failure so the UI can show it directly without
/// leaking Firebase's internal error codes.
class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  fb.User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  /// Emits every time the auth state changes (used by the splash screen
  /// to decide whether to route to Login or Home).
  Stream<fb.User?> authStateChanges() => _auth.authStateChanges();

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(name.trim());

      final user = UserModel(
        id: uid,
        name: name.trim(),
        email: email.trim(),
        isOnline: true,
        lastSeen: DateTime.now(),
      );
      await _db.collection('users').doc(uid).set(user.toMap());
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      await setOnlineStatus(uid, true);
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        // Defensive: user existed in Auth but not Firestore (e.g. migrated).
        final fallback = UserModel(
          id: uid,
          name: credential.user!.displayName ?? 'User',
          email: email.trim(),
          isOnline: true,
        );
        await _db.collection('users').doc(uid).set(fallback.toMap());
        return fallback;
      }
      return UserModel.fromMap(uid, doc.data()!);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> logout() async {
    final uid = currentUid;
    if (uid != null) {
      await setOnlineStatus(uid, false);
    }
    await _auth.signOut();
  }

  Future<void> setOnlineStatus(String uid, bool isOnline) async {
    await _db.collection('users').doc(uid).set({
      'isOnline': isOnline,
      'lastSeen': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  String _mapAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'weak-password':
        return 'Please choose a stronger password (6+ characters).';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
