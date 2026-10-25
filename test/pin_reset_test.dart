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
import 'package:clearnet/data/services/app_pin_reset_service.dart';
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/presentation/screens/pin_pad_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';
import 'pin_pad_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  const storage = FlutterSecureStorage();
  late int unlocked;

  setUp(() async {
    await SharedPreferencesAsync().clear();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PinService.iterations = 1000;
    AppPinResetService.now = DateTime.now;
    unlocked = 0;
  });

  tearDown(() => AppPinResetService.now = DateTime.now);

  Future<void> showPad(
    WidgetTester tester, {
    String pinKey = Constants.appPinKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PinPadScreen(pinKey: pinKey, onSuccess: () => unlocked++),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> savePin(WidgetTester tester, String key, String pin) =>
      tester.runAsync(() => PinService.savePin(key, pin));

  Future<void> tapForgot(WidgetTester tester) async {
    // It's below the number pad, past the bottom of the test screen
    final button = find.byKey(const Key('forgot_pin_button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Forgot PIN is offered for the app PIN only', (tester) async {
    await showPad(tester);
    expect(find.byKey(const Key('forgot_pin_button')), findsOneWidget);

    await showPad(tester, pinKey: Constants.uninstallPinKey);
    expect(find.byKey(const Key('forgot_pin_button')), findsNothing);
  });

  testWidgets('The uninstall PIN lets a new app PIN be set', (tester) async {
    await savePin(tester, Constants.appPinKey, '123456789');
    await savePin(tester, Constants.uninstallPinKey, '987654321');
    await showPad(tester);

    await tapForgot(tester);
    expect(find.text('Enter Uninstall PIN'), findsOneWidget);
    await enterPinOnPad(tester, '987654321');
    await tester.pumpAndSettle();

    expect(find.text('Set New PIN'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('set_pin_field')), '555566667');
    await tester.enterText(
      find.byKey(const Key('confirm_pin_field')),
      '555566667',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    });
    await tester.pumpAndSettle();

    expect(unlocked, 1);
    expect(
      await tester.runAsync(
        () => PinService.verifyPin(Constants.appPinKey, '555566667'),
      ),
      isTrue,
    );
  });

  testWidgets('A wrong uninstall PIN does not reset the app PIN', (
    tester,
  ) async {
    await savePin(tester, Constants.appPinKey, '123456789');
    await savePin(tester, Constants.uninstallPinKey, '987654321');
    await showPad(tester);

    await tapForgot(tester);
    await enterPinOnPad(tester, '111111111');
    await tester.pumpAndSettle();

    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(find.text('Set New PIN'), findsNothing);
    expect(unlocked, 0);
  });

  testWidgets('Without an uninstall PIN, a reset waits 24 hours', (
    tester,
  ) async {
    await savePin(tester, Constants.appPinKey, '123456789');
    await showPad(tester);

    await tapForgot(tester);
    expect(find.text('Reset app PIN?'), findsOneWidget);
    await tester.tap(find.text('Start 24-hour wait'));
    await tester.pumpAndSettle();

    expect(await AppPinResetService.requestedAt(), isNotNull);
    expect(find.textContaining('PIN reset on'), findsOneWidget);
    expect(unlocked, 0);
    expect(await PinService.hasPin(Constants.appPinKey), isTrue);
  });

  testWidgets('Once the wait is over the app PIN is removed and it unlocks', (
    tester,
  ) async {
    await savePin(tester, Constants.appPinKey, '123456789');
    await storage.write(key: Constants.appLockEnabledKey, value: 'true');
    await SharedPreferencesAsync().setBool(Constants.lockSettingsKey, true);
    await AppPinResetService.request();
    AppPinResetService.now = () =>
        DateTime.now().add(const Duration(hours: 24, minutes: 1));

    await showPad(tester);

    expect(unlocked, 1);
    expect(await PinService.hasPin(Constants.appPinKey), isFalse);
    expect(await storage.read(key: Constants.appLockEnabledKey), 'false');
    expect(
      await SharedPreferencesAsync().getBool(Constants.lockSettingsKey),
      isFalse,
    );
    expect(await AppPinResetService.requestedAt(), isNull);
  });

  testWidgets('The PIN is kept before the wait is over', (tester) async {
    await savePin(tester, Constants.appPinKey, '123456789');
    await AppPinResetService.request();
    AppPinResetService.now = () =>
        DateTime.now().add(const Duration(hours: 23));

    await showPad(tester);

    expect(unlocked, 0);
    expect(await PinService.hasPin(Constants.appPinKey), isTrue);
  });

  testWidgets('Entering the right app PIN cancels a requested reset', (
    tester,
  ) async {
    await savePin(tester, Constants.appPinKey, '123456789');
    await AppPinResetService.request();
    await showPad(tester);

    await enterPinOnPad(tester, '123456789');
    await tester.pumpAndSettle();

    expect(unlocked, 1);
    expect(await AppPinResetService.requestedAt(), isNull);
  });

  testWidgets('A requested reset can be cancelled', (tester) async {
    await savePin(tester, Constants.appPinKey, '123456789');
    await AppPinResetService.request();
    await showPad(tester);

    await tapForgot(tester);
    expect(find.text('PIN reset requested'), findsOneWidget);
    await tester.tap(find.text('Cancel reset'));
    await tester.pumpAndSettle();

    expect(await AppPinResetService.requestedAt(), isNull);
    expect(find.textContaining('PIN reset on'), findsNothing);
  });
}
