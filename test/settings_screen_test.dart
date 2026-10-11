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
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/presentation/screens/settings_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inMemoryStore = InMemorySharedPreferencesAsync.empty();
  SharedPreferencesAsyncPlatform.instance = inMemoryStore;

  group('SettingsScreen Visibility Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('clearnet_test_settings_');
      await SharedPreferencesAsync().clear();
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
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

        expect(uninstallPinFinder, findsOneWidget);
        expect(find.text('PIN is set and permanent'), findsOneWidget);
      },
    );

    testWidgets('Theme selection option is present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
    });

    testWidgets('App PIN and Lock settings with PIN relationship test', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(key: Key('app_pin_rel_test'))),
      );
      await tester.pumpAndSettle();

      final setAppPinFinder = find.widgetWithText(
        SwitchListTile,
        'Set app PIN',
      );
      await tester.scrollUntilVisible(
        setAppPinFinder,
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(setAppPinFinder, findsOneWidget);

      final lockSettingsFinder = find.widgetWithText(
        SwitchListTile,
        'Lock settings with PIN',
      );
      expect(lockSettingsFinder, findsOneWidget);

      // Toggling Lock settings when App PIN is not set shows SnackBar
      await tester.tap(lockSettingsFinder);
      await tester.pump();

      expect(find.text('Please set an App PIN first'), findsOneWidget);
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
            'whitelist and unselect all blocked apps. Do you want to proceed?',
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
            'default data. Do you want to proceed?',
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
        find.textContaining('${Constants.appName} is free open-source '
        'software'),
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
      expect(find.textContaining('If you appreciate '
      '${Constants.appName}'), findsOneWidget);
      expect(
        find.text('Support page: ${Constants.buyMeACoffeeUrl}'),
        findsOneWidget,
      );
    });
  });
}
