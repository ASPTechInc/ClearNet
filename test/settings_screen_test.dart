// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/presentation/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen Visibility Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'ClearNet',
        packageName: 'com.example.clearnet',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              return '.';
            },
          );
    });

    testWidgets('Uninstall PIN option is shown and states it is permanent when set', (
      WidgetTester tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(key: Key('no_pin'))),
      );
      await tester.pumpAndSettle();

      final uninstallPinFinder = find.widgetWithText(ListTile, 'Uninstall PIN');
      
      while (uninstallPinFinder.evaluate().isEmpty) {
        await tester.drag(find.byType(ListView), const Offset(0, -50));
        await tester.pump();
      }

      expect(uninstallPinFinder, findsAtLeastNWidgets(1));
      expect(find.textContaining('Set a PIN to prevent'), findsOneWidget);

      // Pre-seed storage with a PIN
      FlutterSecureStorage.setMockInitialValues({'uninstall_pin': '1234'});
      
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(key: Key('with_pin'))),
      );
      await tester.pumpAndSettle();

      while (uninstallPinFinder.evaluate().isEmpty) {
        await tester.drag(find.byType(ListView), const Offset(0, -50));
        await tester.pump();
      }

      expect(uninstallPinFinder, findsAtLeastNWidgets(1));
      expect(find.text('PIN is set and permanent'), findsOneWidget);
      expect(find.text('Remove Uninstall PIN'), findsNothing);
    });

    testWidgets('Theme selection option is present', (
      WidgetTester tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
    });
  });
}
