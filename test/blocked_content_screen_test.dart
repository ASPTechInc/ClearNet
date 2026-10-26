// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/presentation/screens/blocked_content.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();

  group('BlockedContentScreen Widget Tests', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tempDir = Directory.systemTemp.createTempSync('clearnet_test_');
      await SharedPreferencesAsync().clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, (methodCall) async {
            if (methodCall.method == 'getInstalledApps') {
              return <Map<String, String>>[];
            }
            return null;
          });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (methodCall) async {
              return tempDir.path;
            },
          );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            if (message == null) return null;

            String key = '';
            try {
              key = utf8.decode(message.buffer.asUint8List());
            } catch (_) {
              try {
                final decoded = const StandardMessageCodec().decodeMessage(
                  message,
                );
                if (decoded is String) key = decoded;
              } catch (_) {}
            }

            if (key.contains(Constants.blocklistFileName)) {
              final encoded = json.encode({
                'domains': [],
                'keywords': [],
                'whitelist': [],
              });
              return ByteData.view(
                Uint8List.fromList(utf8.encode(encoded)).buffer,
              );
            }

            if (key == 'AssetManifest.bin') {
              return const StandardMessageCodec().encodeMessage(
                <Object?, Object?>{},
              );
            }

            return ByteData.view(
              Uint8List.fromList([
                0x89,
                0x50,
                0x4E,
                0x47,
                0x0D,
                0x0A,
                0x1A,
                0x0A,
                0x00,
                0x00,
                0x00,
                0x0D,
                0x49,
                0x48,
                0x44,
                0x52,
                0x00,
                0x00,
                0x00,
                0x01,
                0x00,
                0x00,
                0x00,
                0x01,
                0x08,
                0x06,
                0x00,
                0x00,
                0x00,
                0x1F,
                0x15,
                0xC4,
                0x89,
                0x00,
                0x00,
                0x00,
                0x0D,
                0x49,
                0x44,
                0x41,
                0x54,
                0x78,
                0x9C,
                0x63,
                0x60,
                0x18,
                0x05,
                0xA3,
                0x00,
                0x00,
                0x00,
                0x02,
                0x00,
                0x01,
                0xE2,
                0x21,
                0xBC,
                0x33,
                0x00,
                0x00,
                0x00,
                0x00,
                0x49,
                0x45,
                0x4E,
                0x44,
                0xAE,
                0x42,
                0x60,
                0x82,
              ]).buffer,
            );
          });

      SharedPreferences.setMockInitialValues({});
      await BlocklistManager.init();
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    Widget createWidgetUnderTest() {
      return const MaterialApp(home: BlockedContentScreen());
    }

    testWidgets('BlockedContentScreen displays all 4 tabs: '
        'Domains, Keywords, Whitelist, Apps', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Blocked content'), findsOneWidget);
      expect(find.text('Domains'), findsOneWidget);
      expect(find.text('Keywords'), findsOneWidget);
      expect(find.text('Whitelist'), findsOneWidget);
      expect(find.text('Apps'), findsOneWidget);
      expect(find.byKey(const Key('domain_input')), findsOneWidget);
    });

    testWidgets('explains the built-in blocklist without a count', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your domains are added to the built-in blocklist of adult domains '
          '(The Block List Project), which always applies. To allow a site '
          'from it, add it to the Whitelist tab.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows how many domains the built-in blocklist has', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, (methodCall) async {
            if (methodCall.method == 'getInstalledApps') {
              return <Map<String, String>>[];
            }
            if (methodCall.method == 'getBundledBlocklistSize') return 953393;
            return null;
          });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('built-in blocklist of 953,393 adult domains'),
        findsOneWidget,
      );
    });

    testWidgets('adds a new domain and displays it in list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final domainInput = find.byKey(const Key('domain_input'));
      final addButton = find.byKey(const Key('add_domain_button'));

      await tester.enterText(domainInput, 'badsite.com');
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('badsite.com'), findsAtLeastNWidgets(1));
    });

    testWidgets('deletes a domain from list', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final domainInput = find.byKey(const Key('domain_input'));
      final addButton = find.byKey(const Key('add_domain_button'));

      await tester.enterText(domainInput, 'removethis.com');
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('removethis.com'), findsAtLeastNWidgets(1));

      final deleteIcon = find.byIcon(Icons.delete);
      if (deleteIcon.evaluate().isEmpty) {
        debugPrint('WIDGET TREE:');
        debugDumpApp();
      }

      // Fallback: find by index if icon not found
      final deleteBtn = deleteIcon.first;

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'removethis.com'), findsNothing);
    });

    testWidgets(
      'Attempting to add a whitelisted site as a blocked domain shows SnackBar',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Add to whitelist first
        await tester.tap(find.text('Whitelist'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('whitelist_input')),
          'safe.com',
        );
        await tester.tap(find.byKey(const Key('add_whitelist_button')));
        await tester.pumpAndSettle();

        // Go back to Domains
        await tester.tap(find.text('Domains'));
        await tester.pumpAndSettle();

        // Try adding same site to domains
        await tester.enterText(
          find.byKey(const Key('domain_input')),
          'safe.com',
        );
        await tester.tap(find.byKey(const Key('add_domain_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('already in the whitelist'), findsOneWidget);
      },
    );

    group('while blocking is on', () {
      setUp(() async {
        await BlocklistManager.addUserDomain('locked.com');
        await BlocklistManager.addUserKeyword('lockedword');
        await BlocklistManager.addUserWhitelist('allowed.com');
        await SharedPreferencesAsync().setBool('is_blocking_enabled', true);
      });

      testWidgets('shows the locked banner', (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('blocking_locked_banner')), findsOneWidget);
      });

      testWidgets('domains can be added but not removed', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete), findsNothing);

        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, 'locked.com'),
            matching: find.byIcon(Icons.lock_outline),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Turn off blocking to remove domains.'),
          findsOneWidget,
        );
        expect(
          await BlocklistManager.loadUserDomains(),
          contains('locked.com'),
        );

        await tester.enterText(
          find.byKey(const Key('domain_input')),
          'newsite.com',
        );
        await tester.tap(find.byKey(const Key('add_domain_button')));
        await tester.pumpAndSettle();

        expect(
          await BlocklistManager.loadUserDomains(),
          contains('newsite.com'),
        );
      });

      testWidgets('domains cannot be edited', (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.text('locked.com'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Turn off blocking to edit rules.'), findsOneWidget);
      });

      testWidgets('keywords cannot be removed', (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Keywords'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, 'lockedword'),
            matching: find.byIcon(Icons.lock_outline),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          await BlocklistManager.loadUserKeywords(),
          contains('lockedword'),
        );
      });

      testWidgets('whitelist entries can be removed but not added', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Whitelist'));
        await tester.pumpAndSettle();

        final input = tester.widget<TextField>(
          find.byKey(const Key('whitelist_input')),
        );
        expect(input.enabled, isFalse);

        await tester.tap(find.byKey(const Key('add_whitelist_button')));
        await tester.pumpAndSettle();
        expect(
          find.text('Turn off blocking to add whitelisted sites.'),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, 'allowed.com'),
            matching: find.byIcon(Icons.delete),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          await BlocklistManager.loadUserWhitelist(),
          isNot(contains('allowed.com')),
        );
      });

      testWidgets('import is locked', (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('import_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Turn off blocking to import a blocklist.'),
          findsOneWidget,
        );
      });
    });
  });

  group('BlockedAppsScreen Widget & Interaction Tests', () {
    final fakeApps = [
      {'name': 'Camera App', 'packageName': 'com.android.camera'},
      {'name': 'Social App', 'packageName': 'com.social.media'},
      {'name': 'Game App', 'packageName': 'com.gaming.fun'},
    ];

    setUp(() async {
      await SharedPreferencesAsync().clear();
      SharedPreferences.setMockInitialValues({});

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(Constants.methodChannelName),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getInstalledApps') {
                return fakeApps;
              }
              return null;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(Constants.methodChannelName),
            null,
          );
    });

    Widget createWidgetUnderTest() {
      return const MaterialApp(home: BlockedContentScreen());
    }

    testWidgets('renders list of installed apps correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apps'));
      await tester.pumpAndSettle();

      expect(find.text('Search apps...'), findsOneWidget);
      expect(find.text('Camera App'), findsOneWidget);
      expect(find.text('Social App'), findsOneWidget);
      expect(find.text('Game App'), findsOneWidget);
    });

    testWidgets('filters apps based on search query', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apps'));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Social');
      await tester.pumpAndSettle();

      expect(find.text('Social App'), findsOneWidget);
      expect(find.text('Camera App'), findsNothing);
      expect(find.text('Game App'), findsNothing);
    });

    testWidgets('toggling switch blocks and unblocks an app', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apps'));
      await tester.pumpAndSettle();

      final cameraSwitch = find.widgetWithText(SwitchListTile, 'Camera App');
      expect(cameraSwitch, findsOneWidget);

      // Tap to block Camera App
      await tester.tap(cameraSwitch);
      await tester.pumpAndSettle();

      List<String>? blocked = await SharedPreferencesAsync().getStringList(
        Constants.blockedAppsKey,
      );
      expect(blocked, contains('com.android.camera'));

      // Tap again to unblock
      await tester.tap(cameraSwitch);
      await tester.pumpAndSettle();

      blocked = await SharedPreferencesAsync().getStringList(
        Constants.blockedAppsKey,
      );
      expect(blocked, isNot(contains('com.android.camera')));
    });

    testWidgets('apps can be blocked but not unblocked while blocking is on', (
      WidgetTester tester,
    ) async {
      await SharedPreferencesAsync().setBool('is_blocking_enabled', true);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apps'));
      await tester.pumpAndSettle();

      final cameraSwitch = find.widgetWithText(SwitchListTile, 'Camera App');

      await tester.tap(cameraSwitch);
      await tester.pumpAndSettle();

      List<String>? blocked = await SharedPreferencesAsync().getStringList(
        Constants.blockedAppsKey,
      );
      expect(blocked, contains('com.android.camera'));

      await tester.tap(cameraSwitch);
      await tester.pumpAndSettle();

      blocked = await SharedPreferencesAsync().getStringList(
        Constants.blockedAppsKey,
      );
      expect(blocked, contains('com.android.camera'));
      expect(find.text('Turn off blocking to unblock apps.'), findsOneWidget);
    });
  });
}
