// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/presentation/screens/pin_screen.dart';

/// Taps Submit and waits for PIN hashing, which runs in a real isolate that
/// the test's fake clock doesn't wait for.
Future<void> submit(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.byType(ElevatedButton));
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinLockScreen Widget & Interaction Tests', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      // Full strength is slow; the algorithm is the same at any count
      PinService.iterations = 1000;
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
      await tester.enterText(find.byType(TextField), '123456789');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Tap Confirm in the dialogue
      expect(find.text('Confirm PIN'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pump();

      // Verify SnackBar for confirmation
      expect(find.text('Re-enter PIN to confirm'), findsOneWidget);
      expect(successCalled, isFalse);

      // 2. Enter matching PIN
      await tester.enterText(find.byType(TextField), '123456789');
      await submit(tester);

      expect(successCalled, isTrue);

      // Only a salted hash is stored, never the PIN itself
      final stored = await const FlutterSecureStorage().read(key: 'app_pin');
      expect(stored, startsWith(r'pbkdf2-sha256$1000$'));
      expect(stored, isNot(contains('123456789')));
      final asyncPin = await SharedPreferencesAsync().getString('app_pin');
      expect(asyncPin, isNull);
    });

    testWidgets('New PINs shorter than 9 digits are rejected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: PinLockScreen(confirmMode: true)),
      );

      await tester.enterText(find.byType(TextField), '12345678');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('PIN must be 8 to 16 digits'), findsOneWidget);
      expect(find.text('Confirm PIN'), findsNothing);
    });

    testWidgets('PIN field accepts digits only, up to 16', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: PinLockScreen(confirmMode: true)),
      );

      await tester.enterText(find.byType(TextField), '12ab34567890123456789');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '1234567890123456');
    });

    testWidgets('Verification succeeds with a hashed PIN', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() => PinService.savePin('app_pin', '987654321'));

      bool successCalled = false;
      await tester.pumpWidget(
        MaterialApp(home: PinLockScreen(onSuccess: () => successCalled = true)),
      );

      await tester.enterText(find.byType(TextField), '987654321');
      await submit(tester);

      expect(successCalled, isTrue);
    });

    testWidgets('Verification rejects a PIN of the wrong length', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() => PinService.savePin('app_pin', '987654321'));

      bool successCalled = false;
      await tester.pumpWidget(
        MaterialApp(home: PinLockScreen(onSuccess: () => successCalled = true)),
      );

      await tester.enterText(find.byType(TextField), '9876');
      await submit(tester);

      expect(find.text('Incorrect PIN'), findsOneWidget);
      expect(successCalled, isFalse);
    });

    testWidgets('A stored PIN that is not a hash never matches', (
      WidgetTester tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({'app_pin': '123456789'});

      bool successCalled = false;
      await tester.pumpWidget(
        MaterialApp(home: PinLockScreen(onSuccess: () => successCalled = true)),
      );

      await tester.enterText(find.byType(TextField), '123456789');
      await submit(tester);

      expect(find.text('Incorrect PIN'), findsOneWidget);
      expect(successCalled, isFalse);
    });

    testWidgets('Verification fails with incorrect PIN', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() => PinService.savePin('app_pin', '987654321'));

      bool successCalled = false;
      await tester.pumpWidget(
        MaterialApp(home: PinLockScreen(onSuccess: () => successCalled = true)),
      );

      await tester.enterText(find.byType(TextField), '987654320');
      await submit(tester);

      expect(find.text('Incorrect PIN'), findsOneWidget);
      expect(successCalled, isFalse);
    });
  });

  group('PinService', () {
    test('PBKDF2 matches the RFC 7914 test vectors', () {
      String hex(List<int> bytes) =>
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final password = 'password'.codeUnits;
      final salt = 'salt'.codeUnits;

      expect(
        hex(PinService.pbkdf2(password, salt, 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        hex(PinService.pbkdf2(password, salt, 4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('isValidPin requires 8 to 16 digits', () {
      expect(PinService.isValidPin('12345678'), isFalse);
      expect(PinService.isValidPin('123456789'), isTrue);
      expect(PinService.isValidPin('1234567890123456'), isTrue);
      expect(PinService.isValidPin('12345678901234567'), isFalse);
      expect(PinService.isValidPin('12345678a'), isFalse);
    });
  });
}
