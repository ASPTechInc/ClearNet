// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/presentation/screens/blocked_sites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlockedSitesScreen Widget Tests', () {
    setUp(() {
      // Mock MethodChannel using the actual instance to be sure
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, (methodCall) async {
        return null;
      });

      // Mock path_provider
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (methodCall) async {
        return '.';
      });

      // Mock Assets robustly
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) return null;
        
        String key = '';
        try {
          key = utf8.decode(message.buffer.asUint8List());
        } catch (_) {
          try {
            final decoded = const StandardMessageCodec().decodeMessage(message);
            if (decoded is String) key = decoded;
          } catch (_) {}
        }

        if (key.contains('blocklist.json')) {
          final encoded = json.encode({'domains': [], 'keywords': []});
          return ByteData.view(Uint8List.fromList(utf8.encode(encoded)).buffer);
        }
        
        if (key == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage(<Object?, Object?>{});
        }

        // Return a valid 1x1 transparent PNG for any image or other asset requests to prevent image loading errors
        return ByteData.view(Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
          0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
          0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x18, 0x05, 0xA3,
          0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33, 0x00, 0x00,
          0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
        ]).buffer);
      });

      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    Widget createWidgetUnderTest() {
      return const MaterialApp(
        home: BlockedSitesScreen(),
      );
    }

    testWidgets('BlockedSitesScreen basic visibility test', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Blocked content'), findsOneWidget);
      expect(find.byKey(const Key('domain_input')), findsOneWidget);
    });
  });
}
