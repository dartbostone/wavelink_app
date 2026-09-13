import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus status = AuthStatus.unknown;
  UserModel? currentUser;
  String? errorMessage;
  bool isLoading = false;

  AuthProvider() {
    _authService.authStateChanges().listen((user) async {
      if (user != null) {
        currentUser = await _authService.getUserModel(user.uid);
        status = AuthStatus.authenticated;
      } else if (_authService.currentUid != null) {
        currentUser = await _authService.getUserModel(_authService.currentUid!);
        status = AuthStatus.authenticated;
      } else if (status != AuthStatus.authenticated) {
        status = AuthStatus.unauthenticated;
        currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) => _run(() async {
    currentUser = await _authService.login(email: email, password: password);
    status = AuthStatus.authenticated;
  });

  Future<bool> register(String name, String email, String password) =>
      _run(() async {
        currentUser = await _authService.register(
          name: name,
          email: email,
          password: password,
        );
        status = AuthStatus.authenticated;
      });

  Future<bool> guestLogin() => _run(() async {
    currentUser = await _authService.login(
      email: 'guest@wavelink.app',
      password: 'password123',
    );
    status = AuthStatus.authenticated;
  });

  Future<bool> updateProfile({required String name, String? avatarUrl}) async {
    final currentUid = uid;
    if (currentUid == null) return false;
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;

    try {
      await UserService().updateProfile(
        currentUid,
        name: cleanName,
        avatarUrl: avatarUrl,
      );
    } catch (_) {}

    if (currentUser != null) {
      currentUser = UserModel(
        id: currentUser!.id,
        name: cleanName,
        email: currentUser!.email,
        avatarUrl: avatarUrl ?? currentUser!.avatarUrl,
        isOnline: currentUser!.isOnline,
        lastSeen: currentUser!.lastSeen,
      );
    } else {
      currentUser = UserModel(
        id: currentUid,
        name: cleanName,
        email: 'user@wavelink.app',
        avatarUrl: avatarUrl,
        isOnline: true,
      );
    }
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  String? get uid => _authService.currentUid;
}
