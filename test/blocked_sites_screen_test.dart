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
    final List<MethodCall> methodLog = <MethodCall>[];

    setUp(() {
      methodLog.clear();
      
      // Mock MethodChannel using the actual instance to be sure
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, (methodCall) async {
        methodLog.add(methodCall);
        return null;
      });

      // Mock Assets
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) return null;
        final String key = utf8.decode(message.buffer.asUint8List());
        if (key.contains('blocklist.json')) {
          final encoded = json.encode({'domains': [], 'keywords': []});
          return ByteData.view(Uint8List.fromList(utf8.encode(encoded)).buffer);
        }
        return null;
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

    testWidgets('can add and remove domains', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('domain_input')), 'example.com');
      await tester.tap(find.byKey(const Key('add_domain_button')));
      await tester.pumpAndSettle();

      expect(find.text('example.com'), findsOneWidget);

      // Remove
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      expect(find.text('example.com'), findsNothing);
    });
  });
}
