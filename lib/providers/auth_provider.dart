import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Exposes auth state + actions to the whole widget tree via [Provider].
/// Screens read this instead of talking to [AuthService] directly, which
/// keeps Firebase calls out of the UI layer (spec: "business logic lives
/// in services; providers connect services to the UI").
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus status = AuthStatus.unknown;
  UserModel? currentUser;
  String? errorMessage;
  bool isLoading = false;

  AuthProvider() {
    _authService.authStateChanges().listen((user) async {
      if (user == null) {
        status = AuthStatus.unauthenticated;
        currentUser = null;
      } else {
        status = AuthStatus.authenticated;
      }
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) => _run(() async {
        currentUser = await _authService.login(email: email, password: password);
        status = AuthStatus.authenticated;
      });

  Future<bool> register(String name, String email, String password) => _run(() async {
        currentUser = await _authService.register(name: name, email: email, password: password);
        status = AuthStatus.authenticated;
      });

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
