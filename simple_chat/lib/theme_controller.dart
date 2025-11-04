import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'app_theme_mode';
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final str = sp.getString(_key);
    if (str == 'dark') {
      _mode = ThemeMode.dark;
    } else if (str == 'light') {
      _mode = ThemeMode.light;
    } else {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    final sp = await SharedPreferences.getInstance();
    if (_mode == ThemeMode.light) {
      _mode = ThemeMode.dark;
      await sp.setString(_key, 'dark');
    } else {
      _mode = ThemeMode.light;
      await sp.setString(_key, 'light');
    }
    notifyListeners();
  }
}
