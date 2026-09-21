// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/presentation/screens/pin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinLockScreen Widget & Interaction Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    testWidgets('Initial PIN setup (confirmMode) requires double entry', (
      WidgetTester tester,
    ) async {
      bool successCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PinLockScreen(
            confirmMode: true,
            onSuccess: () => successCalled = true,
          ),
        ),
      );

      // 1. Enter first PIN
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Tap Confirm in the dialog
      expect(find.text('Confirm PIN'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pump();

      // Verify SnackBar for confirmation
      expect(find.text('Re-enter PIN to confirm'), findsOneWidget);
      expect(successCalled, isFalse);

      // 2. Enter matching PIN
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(successCalled, isTrue);

      // Verify storage
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('uninstall_pin'), '1234');
    });

    testWidgets('Verification mode fails with incorrect PIN', (
      WidgetTester tester,
    ) async {
      // Pre-seed storage with a PIN
      FlutterSecureStorage.setMockInitialValues({'uninstall_pin': '9999'});

      bool successCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PinLockScreen(
            confirmMode: false,
            onSuccess: () => successCalled = true,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Incorrect PIN'), findsOneWidget);
      expect(successCalled, isFalse);
    });

    testWidgets('Verification mode succeeds with correct PIN', (
      WidgetTester tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({'uninstall_pin': '8888'});

      bool successCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PinLockScreen(
            confirmMode: false,
            onSuccess: () => successCalled = true,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '8888');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(successCalled, isTrue);
    });
  });
}
