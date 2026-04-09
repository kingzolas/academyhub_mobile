import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _legacyIsDarkModeKey = 'isDarkMode';
  static const String _themeModeKey = 'themeMode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> toggleTheme(bool isOn) async {
    await setThemeMode(isOn ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);

    if (mode == ThemeMode.system) {
      await prefs.remove(_legacyIsDarkModeKey);
    } else {
      await prefs.setBool(_legacyIsDarkModeKey, mode == ThemeMode.dark);
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeModeKey);

    if (savedMode == ThemeMode.dark.name) {
      _themeMode = ThemeMode.dark;
      notifyListeners();
      return;
    }

    if (savedMode == ThemeMode.light.name) {
      _themeMode = ThemeMode.light;
      notifyListeners();
      return;
    }

    if (savedMode == ThemeMode.system.name) {
      _themeMode = ThemeMode.system;
      notifyListeners();
      return;
    }

    final isDark = prefs.getBool(_legacyIsDarkModeKey);
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }
}
