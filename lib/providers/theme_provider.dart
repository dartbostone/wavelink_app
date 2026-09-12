import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bonus 3 — Dark Mode, persisted across app restarts.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  ThemeMode mode = ThemeMode.system;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'dark') {
      mode = ThemeMode.dark;
    } else if (saved == 'light') {
      mode = ThemeMode.light;
    } else {
      mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
