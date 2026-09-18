// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

class ThemeService {
  factory ThemeService() => _instance;
  ThemeService._internal();
  static final ThemeService _instance = ThemeService._internal();

  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(Constants.themeModeKey) ?? 'system';
    themeModeNotifier.value = _themeModeFromName(themeName);
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.themeModeKey, mode.name);
  }

  ThemeMode _themeModeFromName(String name) {
    switch (name) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}
