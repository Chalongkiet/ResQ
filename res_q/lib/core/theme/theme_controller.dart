import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;
    notifyListeners();
  }

  void useSystemTheme() {
    setThemeMode(ThemeMode.system);
  }

  void useLightTheme() {
    setThemeMode(ThemeMode.light);
  }

  void useDarkTheme() {
    setThemeMode(ThemeMode.dark);
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      useLightTheme();
    } else {
      useDarkTheme();
    }
  }
}
