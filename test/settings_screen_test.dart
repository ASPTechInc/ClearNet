// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/presentation/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen Visibility Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    testWidgets('Remove Uninstall PIN option is hidden when no PIN is set', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set Uninstall PIN'), findsOneWidget);
      expect(find.text('Remove Uninstall PIN'), findsNothing);
    });

    testWidgets('Remove Uninstall PIN option is shown when PIN is set', (
      WidgetTester tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({'uninstall_pin': '1234'});

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set Uninstall PIN'), findsOneWidget);
      expect(find.text('Remove Uninstall PIN'), findsOneWidget);
    });

    testWidgets('Theme selection option is present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
    });
  });
}
