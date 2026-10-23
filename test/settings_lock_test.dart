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
import 'package:clearnet/presentation/navigation/bottom_nav_bar.dart';
import 'package:clearnet/shared/utilities/constants.dart';
import 'package:clearnet/shared/utilities/helpers.dart';

/// Tests that the Settings tab lock is unlocked with the app PIN.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
    PinService.iterations = 1000;
    AppSession.isSettingsUnlocked = false;
  });

  Future<void> lockSettingsWithAppPin(WidgetTester tester) async {
    await tester.runAsync(
      () => PinService.savePin(Constants.appPinKey, '123456789'),
    );
    await SharedPreferencesAsync().setBool(Constants.lockSettingsKey, true);
  }

  Widget guardedSettings() => const MaterialApp(
    home: PinGuardedTab(child: Scaffold(body: Text('Settings content'))),
  );

  Future<void> enterPin(WidgetTester tester, String pin) async {
    await tester.enterText(find.byType(TextField), pin);
    await tester.runAsync(() async {
      await tester.tap(find.byType(ElevatedButton));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('Settings open without a PIN when the lock is off', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(guardedSettings());
    await tester.pumpAndSettle();

    expect(find.text('Settings content'), findsOneWidget);
  });

  testWidgets('the app PIN unlocks Settings', (WidgetTester tester) async {
    await lockSettingsWithAppPin(tester);
    await tester.pumpWidget(guardedSettings());
    await tester.pumpAndSettle();

    expect(find.text('Verify App PIN'), findsOneWidget);
    expect(find.text('Settings content'), findsNothing);

    await enterPin(tester, '123456789');

    expect(find.text('Settings content'), findsOneWidget);
    expect(AppSession.isSettingsUnlocked, isTrue);
  });

  testWidgets('a wrong PIN keeps Settings locked', (WidgetTester tester) async {
    await lockSettingsWithAppPin(tester);
    await tester.pumpWidget(guardedSettings());
    await tester.pumpAndSettle();

    await enterPin(tester, '987654321');

    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(find.text('Settings content'), findsNothing);
  });
}
