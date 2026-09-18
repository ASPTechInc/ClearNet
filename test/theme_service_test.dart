// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeService Unit Tests', () {
    late ThemeService themeService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      themeService = ThemeService();
      // Reset notifier to system for clean tests
      ThemeService.themeModeNotifier.value = ThemeMode.system;
    });

    test('init loads theme mode from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        Constants.themeModeKey: 'dark',
      });

      await themeService.init();

      expect(ThemeService.themeModeNotifier.value, ThemeMode.dark);
    });

    test('init defaults to system theme mode if not set', () async {
      await themeService.init();
      expect(ThemeService.themeModeNotifier.value, ThemeMode.system);
    });

    test('updateThemeMode updates notifier and SharedPreferences', () async {
      await themeService.updateThemeMode(ThemeMode.light);

      expect(ThemeService.themeModeNotifier.value, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Constants.themeModeKey), 'light');
    });
  });
}
