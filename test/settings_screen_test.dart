// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/data/services/app_nav_service.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/presentation/screens/settings_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';
import 'package:clearnet/shared/utilities/helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inMemoryStore = InMemorySharedPreferencesAsync.empty();
  SharedPreferencesAsyncPlatform.instance = inMemoryStore;

  /// The About section starts collapsed, so its tiles are not built until it
  /// is expanded.
  Future<void> expandAboutSection(WidgetTester tester) async {
    final about = find.text('About');
    await tester.scrollUntilVisible(
      about,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(about);
    await tester.pumpAndSettle();
  }

  group('SettingsScreen Visibility Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('clearnet_test_settings_');
      await SharedPreferencesAsync().clear();
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      PinService.iterations = 1000;
      AppSession.isSettingsUnlocked = false;
      PackageInfo.setMockInitialValues(
        appName: Constants.appName,
        packageName: 'com.example.clearnet',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              return tempDir.path;
            },
          );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(Constants.methodChannelName),
            (MethodCall methodCall) async {
              return null;
            },
          );
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets(
      'Uninstall PIN option is shown and states it is permanent when set',
      (WidgetTester tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        await tester.pumpWidget(
          const MaterialApp(home: SettingsScreen(key: Key('no_pin'))),
        );
        await tester.pumpAndSettle();

        final uninstallPinFinder = find.widgetWithText(
          ListTile,
          'Uninstall PIN',
        );
        await tester.scrollUntilVisible(
          uninstallPinFinder,
          200.0,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        expect(uninstallPinFinder, findsOneWidget);
        expect(find.textContaining('Set a PIN to prevent'), findsOneWidget);

        // Pre-seed storage with a PIN
        FlutterSecureStorage.setMockInitialValues({
          Constants.uninstallPinKey: '1234',
        });

        await tester.pumpWidget(
          const MaterialApp(home: SettingsScreen(key: Key('with_pin'))),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          uninstallPinFinder,
          200.0,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        // The mock channel reports device admin as off, so the PIN does not
        // protect anything yet
        expect(uninstallPinFinder, findsOneWidget);
        expect(find.textContaining('Not active'), findsOneWidget);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(Constants.methodChannelName),
              (MethodCall methodCall) async =>
                  methodCall.method == 'isDeviceAdminActive' ? true : null,
            );
        await tester.pumpWidget(
          const MaterialApp(home: SettingsScreen(key: Key('with_admin'))),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          uninstallPinFinder,
          200.0,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        expect(find.text('PIN is set and permanent'), findsOneWidget);
      },
    );

    testWidgets('Setting the uninstall PIN asks for device admin', (
      WidgetTester tester,
    ) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(Constants.methodChannelName),
            (MethodCall methodCall) async {
              calls.add(methodCall.method);
              return null;
            },
          );
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(key: Key('admin_request'))),
      );
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(ListTile, 'Uninstall PIN');
      await tester.scrollUntilVisible(
        tile,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('set_pin_field')),
        '987654321',
      );
      await tester.enterText(
        find.byKey(const Key('confirm_pin_field')),
        '987654321',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      expect(calls, contains('requestDeviceAdmin'));
    });

    testWidgets('Theme selection option is present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
    });

    testWidgets(
      'Replay app tour resets tour flags and jumps to Protection tab',
      (WidgetTester tester) async {
        final prefs = SharedPreferencesAsync();
        await prefs.setBool('has_seen_app_tour', true);
        await prefs.setBool(AppTourManager.protectionTourKey, true);
        await prefs.setBool(AppTourManager.contentTourKey, true);
        await prefs.setBool(AppTourManager.settingsTourKey, true);
        AppNavigationService.jumpToTab(2);

        await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
        await tester.pumpAndSettle();

        final replayTourFinder = find.widgetWithText(
          ListTile,
          'Replay app tour',
        );
        await tester.scrollUntilVisible(
          replayTourFinder,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(replayTourFinder);
        await tester.pumpAndSettle();

        expect(AppNavigationService.controller.index, 0);
        expect(await prefs.getBool('has_seen_app_tour'), isNull);
        expect(await prefs.getBool(AppTourManager.protectionTourKey), isNull);
        expect(await prefs.getBool(AppTourManager.contentTourKey), isNull);
        expect(await prefs.getBool(AppTourManager.settingsTourKey), isNull);
      },
    );

    /// Saves a hashed app PIN and sets the two switches' stored state.
    Future<void> seedLocks(
      WidgetTester tester, {
      required bool appLock,
      bool lockSettings = false,
    }) async {
      await tester.runAsync(
        () => PinService.savePin(Constants.appPinKey, '123456789'),
      );
      await const FlutterSecureStorage().write(
        key: Constants.appLockEnabledKey,
        value: '$appLock',
      );
      await SharedPreferencesAsync().setBool(
        Constants.lockSettingsKey,
        lockSettings,
      );
    }

    /// Shows Settings scrolled so the switch titled [title] is visible.
    Future<void> showSecurity(
      WidgetTester tester, {
      String title = 'Lock settings with PIN',
    }) async {
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(key: Key('security_test'))),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(SwitchListTile, title),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
    }

    bool switchValue(WidgetTester tester, String title) => tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
        .value;

    testWidgets('Lock settings cannot be turned on until Set app PIN is on', (
      WidgetTester tester,
    ) async {
      await showSecurity(tester);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Lock settings with PIN'),
      );
      await tester.pump();

      expect(find.text('Turn on "Set app PIN" first'), findsOneWidget);
      expect(find.text('Set App PIN'), findsNothing);
      expect(switchValue(tester, 'Lock settings with PIN'), isFalse);
      expect(
        await SharedPreferencesAsync().getBool(Constants.lockSettingsKey),
        isNot(isTrue),
      );
    });

    testWidgets('Lock settings can be turned on once Set app PIN is on', (
      WidgetTester tester,
    ) async {
      await seedLocks(tester, appLock: true);
      await showSecurity(tester);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Lock settings with PIN'),
      );
      await tester.pumpAndSettle();

      expect(switchValue(tester, 'Lock settings with PIN'), isTrue);
      expect(
        await SharedPreferencesAsync().getBool(Constants.lockSettingsKey),
        isTrue,
      );
    });

    testWidgets('Set app PIN stays on while Lock settings is on', (
      WidgetTester tester,
    ) async {
      await seedLocks(tester, appLock: true, lockSettings: true);
      await showSecurity(tester, title: 'Set app PIN');

      await tester.tap(find.widgetWithText(SwitchListTile, 'Set app PIN'));
      await tester.pump();

      expect(
        find.text('Turn off "Lock settings with PIN" first'),
        findsOneWidget,
      );
      expect(switchValue(tester, 'Set app PIN'), isTrue);
      expect(
        await const FlutterSecureStorage().read(
          key: Constants.appLockEnabledKey,
        ),
        'true',
      );
    });

    testWidgets('Set app PIN can be turned off when Lock settings is off', (
      WidgetTester tester,
    ) async {
      await seedLocks(tester, appLock: true);
      await showSecurity(tester, title: 'Set app PIN');

      await tester.tap(find.widgetWithText(SwitchListTile, 'Set app PIN'));
      await tester.pumpAndSettle();

      expect(switchValue(tester, 'Set app PIN'), isFalse);
      expect(
        await const FlutterSecureStorage().read(
          key: Constants.appLockEnabledKey,
        ),
        'false',
      );
    });

    testWidgets('Set app PIN opens a dialog with PIN and Confirm PIN', (
      WidgetTester tester,
    ) async {
      await showSecurity(tester, title: 'Set app PIN');

      await tester.tap(find.widgetWithText(SwitchListTile, 'Set app PIN'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Set App PIN'), findsOneWidget);
      expect(find.byKey(const Key('set_pin_field')), findsOneWidget);
      expect(find.byKey(const Key('confirm_pin_field')), findsOneWidget);
    });

    testWidgets('Set App PIN dialog rejects PINs that do not match', (
      WidgetTester tester,
    ) async {
      await showSecurity(tester, title: 'Set app PIN');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Set app PIN'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('set_pin_field')),
        '123456789',
      );
      await tester.enterText(
        find.byKey(const Key('confirm_pin_field')),
        '123456780',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('PINs do not match'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(await PinService.hasPin(Constants.appPinKey), isFalse);
    });

    testWidgets('Set App PIN dialog saves the PIN and turns app lock on', (
      WidgetTester tester,
    ) async {
      await showSecurity(tester, title: 'Set app PIN');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Set app PIN'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('set_pin_field')),
        '123456789',
      );
      await tester.enterText(
        find.byKey(const Key('confirm_pin_field')),
        '123456789',
      );
      // Hashing runs in a real isolate, which the fake clock does not wait for
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('App PIN set successfully'), findsOneWidget);
      expect(switchValue(tester, 'Set app PIN'), isTrue);
      expect(
        await tester.runAsync(
          () => PinService.verifyPin(Constants.appPinKey, '123456789'),
        ),
        isTrue,
      );
    });

    /// Fills in the set-PIN dialog with [pin] twice and saves it.
    Future<void> saveInDialog(WidgetTester tester, String pin) async {
      await tester.enterText(find.byKey(const Key('set_pin_field')), pin);
      await tester.enterText(find.byKey(const Key('confirm_pin_field')), pin);
      // Hashing runs in a real isolate, which the fake clock does not wait for
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
    }

    Future<void> tapTile(WidgetTester tester, String title) async {
      final tile = find.widgetWithText(ListTile, title);
      await tester.scrollUntilVisible(
        tile,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    testWidgets('Change app PIN asks for the current and new PIN in a dialog', (
      WidgetTester tester,
    ) async {
      await seedLocks(tester, appLock: true);
      await showSecurity(tester, title: 'Set app PIN');
      await tapTile(tester, 'Change app PIN');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Change App PIN'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('current_pin_field')),
        '123456789',
      );
      await saveInDialog(tester, '111122223');

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('App PIN changed successfully'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => PinService.verifyPin(Constants.appPinKey, '111122223'),
        ),
        isTrue,
      );
    });

    testWidgets('Change app PIN keeps the old PIN if the current is wrong', (
      WidgetTester tester,
    ) async {
      await seedLocks(tester, appLock: true);
      await showSecurity(tester, title: 'Set app PIN');
      await tapTile(tester, 'Change app PIN');

      await tester.enterText(
        find.byKey(const Key('current_pin_field')),
        '999999999',
      );
      await saveInDialog(tester, '111122223');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Incorrect PIN'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => PinService.verifyPin(Constants.appPinKey, '123456789'),
        ),
        isTrue,
      );
    });

    testWidgets('Change app PIN rejects a new PIN equal to the current PIN', (
      WidgetTester tester,
    ) async {
      await seedLocks(tester, appLock: true);
      await showSecurity(tester, title: 'Set app PIN');
      await tapTile(tester, 'Change app PIN');

      await tester.enterText(
        find.byKey(const Key('current_pin_field')),
        '123456789',
      );
      await saveInDialog(tester, '123456789');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('New PIN must be different from\nthe current PIN'),
        findsOneWidget,
      );
      expect(find.text('App PIN changed successfully'), findsNothing);
    });

    testWidgets('Uninstall PIN is set in a dialog after the warning', (
      WidgetTester tester,
    ) async {
      await showSecurity(tester, title: 'Set app PIN');
      await tapTile(tester, 'Uninstall PIN');

      expect(find.text('Set permanent PIN'), findsOneWidget);
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      expect(find.text('Set Uninstall PIN'), findsOneWidget);
      expect(find.byKey(const Key('confirm_pin_field')), findsOneWidget);
      await saveInDialog(tester, '987654321');

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Uninstall PIN set successfully'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => PinService.verifyPin(Constants.uninstallPinKey, '987654321'),
        ),
        isTrue,
      );
    });

    testWidgets('Uninstall PIN cannot be the same as the app PIN', (
      WidgetTester tester,
    ) async {
      await seedLocks(tester, appLock: true);
      await showSecurity(tester, title: 'Set app PIN');
      await tapTile(tester, 'Uninstall PIN');
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      await saveInDialog(tester, '123456789');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('PIN must be different from\nthe app PIN'),
        findsOneWidget,
      );
      expect(await PinService.hasPin(Constants.uninstallPinKey), isFalse);
    });

    testWidgets('Change app PIN rejects a new PIN equal to the uninstall PIN', (
      WidgetTester tester,
    ) async {
      await seedLocks(tester, appLock: true);
      await tester.runAsync(
        () => PinService.savePin(Constants.uninstallPinKey, '987654321'),
      );
      await showSecurity(tester, title: 'Set app PIN');
      await tapTile(tester, 'Change app PIN');

      await tester.enterText(
        find.byKey(const Key('current_pin_field')),
        '123456789',
      );
      await saveInDialog(tester, '987654321');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('PIN must be different from\nthe uninstall PIN'),
        findsOneWidget,
      );
      expect(
        await tester.runAsync(
          () => PinService.verifyPin(Constants.appPinKey, '123456789'),
        ),
        isTrue,
      );
    });

    testWidgets(
      'Clear content dialog opens and clears blocklist & blocked apps '
      'on confirm',
      (WidgetTester tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (ByteData? message) async {
              if (message == null) return null;
              final String key = utf8.decode(message.buffer.asUint8List());
              if (key.contains(Constants.blocklistFileName)) {
                final encoded = json.encode({
                  'domains': ['example.com'],
                  'keywords': ['test'],
                  'whitelist': ['safe.com'],
                });
                return ByteData.view(
                  Uint8List.fromList(utf8.encode(encoded)).buffer,
                );
              }
              return null;
            });

        await tester.pumpWidget(
          const MaterialApp(home: SettingsScreen(key: Key('clear_test'))),
        );
        await tester.pumpAndSettle();

        final clearFinder = find.widgetWithText(ListTile, 'Clear content');
        await tester.scrollUntilVisible(
          clearFinder,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(clearFinder);
        await tester.pumpAndSettle();

        expect(find.text('Clear content'), findsAtLeastNWidgets(1));
        expect(
          find.text(
            'This will remove all items from blocked websites, keywords, '
            'whitelist and unselect all blocked apps. The built-in blocklist '
            'of adult domains still applies.'
            '\n\nDo you want to proceed?',
          ),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(TextButton, 'Clear'));
        await tester.pumpAndSettle();

        expect(await BlocklistManager.loadUserDomains(), isEmpty);
        expect(await BlocklistManager.loadUserKeywords(), isEmpty);
        expect(await BlocklistManager.loadUserWhitelist(), isEmpty);

        final prefs = SharedPreferencesAsync();
        expect(
          await prefs.getStringList(Constants.blockedAppsKey) ?? [],
          isEmpty,
        );
      },
    );

    testWidgets(
      'Reset content dialog opens and resets content to defaults on confirm',
      (WidgetTester tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (ByteData? message) async {
              if (message == null) return null;
              final String key = utf8.decode(message.buffer.asUint8List());
              if (key.contains(Constants.blocklistFileName)) {
                final encoded = json.encode({
                  'domains': ['example.com'],
                  'keywords': ['test'],
                  'whitelist': ['safe.com'],
                });
                return ByteData.view(
                  Uint8List.fromList(utf8.encode(encoded)).buffer,
                );
              }
              return null;
            });

        await tester.pumpWidget(
          const MaterialApp(home: SettingsScreen(key: Key('reset_test'))),
        );
        await tester.pumpAndSettle();

        final resetFinder = find.widgetWithText(ListTile, 'Reset content');
        await tester.scrollUntilVisible(
          resetFinder,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(resetFinder);
        await tester.pumpAndSettle();

        expect(find.text('Reset content'), findsAtLeastNWidgets(1));
        expect(
          find.text(
            'This will reset blocked sites, keywords and whitelist to '
            'default data. The built-in blocklist of adult domains still '
            'applies.'
            '\n\nDo you want to proceed?',
          ),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(TextButton, 'Reset'));
        await tester.pumpAndSettle();

        expect(
          await BlocklistManager.loadUserDomains(),
          contains('example.com'),
        );
        expect(await BlocklistManager.loadUserKeywords(), contains('test'));
        expect(
          await BlocklistManager.loadUserWhitelist(),
          contains('safe.com'),
        );
      },
    );

    testWidgets('Privacy policy dialog opens in-app offline view', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            if (message == null) return null;
            final String key = utf8.decode(message.buffer.asUint8List());
            if (key.contains('PRIVACY_POLICY.md')) {
              return ByteData.view(
                Uint8List.fromList(
                  utf8.encode('Offline Privacy Policy Content'),
                ).buffer,
              );
            }
            return null;
          });

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(key: Key('privacy_test'))),
      );
      await tester.pumpAndSettle();
      await expandAboutSection(tester);

      final privacyFinder = find.widgetWithText(ListTile, 'Privacy policy');
      await tester.scrollUntilVisible(
        privacyFinder,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(privacyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Privacy policy'), findsAtLeastNWidgets(1));
      expect(find.text('Offline Privacy Policy Content'), findsOneWidget);
    });

    testWidgets('Licence dialog opens in-app offline view', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            if (message == null) return null;
            final String key = utf8.decode(message.buffer.asUint8List());
            if (key.contains('LICENSE')) {
              return ByteData.view(
                Uint8List.fromList(utf8.encode('MIT License Content')).buffer,
              );
            }
            return null;
          });

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(key: Key('license_test'))),
      );
      await tester.pumpAndSettle();
      await expandAboutSection(tester);

      final licenseFinder = find.widgetWithText(ListTile, 'Licence');
      await tester.scrollUntilVisible(
        licenseFinder,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(licenseFinder);
      await tester.pumpAndSettle();

      expect(find.text('Licence'), findsAtLeastNWidgets(1));
      expect(find.text('MIT Licence'), findsOneWidget);
      expect(find.text('MIT License Content'), findsOneWidget);
    });

    testWidgets('Source code dialog opens in-app offline view', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(key: Key('source_test'))),
      );
      await tester.pumpAndSettle();
      await expandAboutSection(tester);

      final sourceFinder = find.widgetWithText(ListTile, 'Source code');
      await tester.scrollUntilVisible(
        sourceFinder,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(sourceFinder);
      await tester.pumpAndSettle();

      expect(find.text('Source code'), findsAtLeastNWidgets(1));
      expect(
        find.textContaining(
          '${Constants.appName} is free open-source '
          'software',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Repository: ${Constants.githubRepoUrl}'),
        findsOneWidget,
      );
    });

    testWidgets('Donate dialog opens in-app offline view', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(key: Key('donate_test'))),
      );
      await tester.pumpAndSettle();
      await expandAboutSection(tester);

      final donateFinder = find.widgetWithText(ListTile, 'Donate');
      await tester.scrollUntilVisible(
        donateFinder,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(donateFinder);
      await tester.pumpAndSettle();

      expect(find.text('Support ${Constants.appName}'), findsOneWidget);
      expect(
        find.textContaining(
          'If you appreciate '
          '${Constants.appName}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Support page: ${Constants.buyMeACoffeeUrl}'),
        findsOneWidget,
      );
    });
  });
}
