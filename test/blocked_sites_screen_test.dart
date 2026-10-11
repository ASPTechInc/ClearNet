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
import 'package:clearnet/presentation/screens/blocked_sites.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();

  group('BlockedSitesScreen Widget Tests', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tempDir = Directory.systemTemp.createTempSync('clearnet_test_');
      await SharedPreferencesAsync().clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, (methodCall) async {
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
      return const MaterialApp(home: BlockedSitesScreen());
    }

    testWidgets(
      'BlockedSitesScreen displays all 3 tabs: Domains, Keywords, Whitelist',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Blocked content'), findsOneWidget);
        expect(find.text('Domains'), findsOneWidget);
        expect(find.text('Keywords'), findsOneWidget);
        expect(find.text('Whitelist'), findsOneWidget);
        expect(find.byKey(const Key('domain_input')), findsOneWidget);
      },
    );

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
  });
}
