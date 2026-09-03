import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class ThemeProvider extends ChangeNotifier {
  /// No stored preference → follow the device.
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// True when the app is currently rendering dark, whether by explicit
  /// choice or because the device is in dark mode.
  bool get isDarkMode => _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.get(AppConstants.themeKey);
    if (stored is bool) {
      // Legacy two-state pref
      _themeMode = stored ? ThemeMode.dark : ThemeMode.light;
    } else if (stored is String) {
      _themeMode = ThemeMode.values.firstWhere((m) => m.name == stored, orElse: () => ThemeMode.system);
    }
    notifyListeners();
  }

  /// Switch between explicit light and dark (from the More-tab switch).
  Future<void> toggleTheme() => setTheme(isDarkMode ? ThemeMode.light : ThemeMode.dark);

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.themeKey, mode.name);
    notifyListeners();
  }
}
