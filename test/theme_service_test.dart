// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inMemoryStore = InMemorySharedPreferencesAsync.empty();
  SharedPreferencesAsyncPlatform.instance = inMemoryStore;

  group('ThemeService Unit Tests', () {
    late ThemeService themeService;

    setUp(() async {
      await SharedPreferencesAsync().clear();
      SharedPreferences.setMockInitialValues({});
      themeService = ThemeService();
      ThemeService.themeModeNotifier.value = ThemeMode.system;
    });

    test('init loads theme mode from SharedPreferences', () async {
      await SharedPreferencesAsync().setString(Constants.themeModeKey, 'dark');

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

      final saved = await SharedPreferencesAsync().getString(
        Constants.themeModeKey,
      );
      expect(saved, 'light');
    });
  });
}
