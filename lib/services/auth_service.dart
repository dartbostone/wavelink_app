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

  Future<UserModel?> getUserModel(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(uid, doc.data()!);
      }
    } catch (_) {}
    final fbUser = _auth.currentUser;
    if (fbUser != null && fbUser.uid == uid) {
      return UserModel(
        id: uid,
        name: fbUser.displayName?.isNotEmpty == true
            ? fbUser.displayName!
            : 'User',
        email: fbUser.email ?? '',
        isOnline: true,
      );
    }
    return null;
  }

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
      final user = credential.user!;
      final uid = user.uid;
      try {
        await user.updateDisplayName(name.trim());
      } catch (_) {}

      final userModel = UserModel(
        id: uid,
        name: name.trim(),
        email: email.trim(),
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      try {
        await _db.collection('users').doc(uid).set(userModel.toMap());
      } catch (_) {}
      return userModel;
    } catch (e) {
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
    } catch (e) {
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
    try {
      await _db.collection('users').doc(uid).set({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  String _mapAuthError(Object e) {
    if (e is fb.FirebaseAuthException) {
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
        case 'operation-not-allowed':
          return 'Email/Password sign-in is disabled in Firebase Console. Please enable Email/Password under Authentication > Sign-in method.';
        default:
          return e.message ?? 'Authentication failed (${e.code}).';
      }
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Firestore permission denied. Please update your Security Rules in Firebase Console.';
        case 'unavailable':
          return 'Firestore service unavailable. Please check your network connection.';
        default:
          return e.message ?? 'Database error (${e.code}).';
      }
    }
    final msg = e.toString().replaceFirst('Exception: ', '');
    return msg.isNotEmpty ? msg : 'An unexpected error occurred.';
  }
}
