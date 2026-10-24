// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/data/services/app_lock_service.dart';
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/presentation/screens/app_lock_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

/// Types [pin] on the number pad.
Future<void> typePin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.byKey(Key('pin_key_$digit')));
  }
  await tester.pump();
}

/// Taps the tick and waits for PIN hashing, which runs in a real isolate that
/// the test's fake clock doesn't wait for.
Future<void> submit(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const Key('pin_key_enter')));
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pumpAndSettle();
}

/// Moves the app to the background or back, as Android would.
Future<void> setLifecycle(WidgetTester tester, AppLifecycleState state) async {
  tester.binding.handleAppLifecycleStateChanged(state);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inMemoryStore = InMemorySharedPreferencesAsync.empty();
  SharedPreferencesAsyncPlatform.instance = inMemoryStore;
  final List<MethodCall> methodLog = <MethodCall>[];

  setUp(() async {
    await SharedPreferencesAsync().clear();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PinService.iterations = 1000;
    AppLockService.resetExpectation();
    methodLog.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(Constants.methodChannelName),
          (MethodCall call) async {
            methodLog.add(call);
            return null;
          },
        );
  });

  /// Saves [pin] as the app PIN (hashed) and turns app lock on or off.
  Future<void> setAppPin(
    WidgetTester tester, {
    String pin = '123456789',
    bool lockEnabled = true,
  }) async {
    await tester.runAsync(() => PinService.savePin(Constants.appPinKey, pin));
    await const FlutterSecureStorage().write(
      key: Constants.appLockEnabledKey,
      value: '$lockEnabled',
    );
  }

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: AppLockScreen(child: Scaffold(body: Text('Home Screen'))),
    );
  }

  bool closedApp() => methodLog.any((call) => call.method == 'closeApp');

  group('AppLockScreen Tests', () {
    testWidgets('shows the app straight away if no app PIN is enabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('shows the number pad if App PIN set and App Lock enabled', (
      WidgetTester tester,
    ) async {
      await setAppPin(tester);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('pin_key_0')), findsOneWidget);
      expect(find.text('Enter PIN'), findsOneWidget);

      await typePin(tester, '123456789');
      await submit(tester);

      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets(
      'shows the app straight away if the PIN is set but app lock is off',
      (WidgetTester tester) async {
        await setAppPin(tester, lockEnabled: false);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.text('Enter PIN'), findsNothing);
      },
    );

    testWidgets('stays locked after a wrong PIN', (WidgetTester tester) async {
      await setAppPin(tester);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await typePin(tester, '987654321');
      await submit(tester);

      expect(find.text('Home Screen'), findsNothing);
      expect(find.text('Enter PIN'), findsOneWidget);
      expect(find.text('Incorrect PIN'), findsOneWidget);
    });

    testWidgets('tick is disabled until the PIN is long enough', (
      WidgetTester tester,
    ) async {
      await setAppPin(tester);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      FilledButton enter() =>
          tester.widget<FilledButton>(find.byKey(const Key('pin_key_enter')));

      await typePin(tester, '1234567');
      expect(enter().onPressed, isNull);

      await typePin(tester, '8');
      expect(enter().onPressed, isNotNull);
    });

    testWidgets('C clears and backspace removes one digit', (
      WidgetTester tester,
    ) async {
      await setAppPin(tester);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // A wrong digit is cleared with backspace, then the right PIN still works
      await typePin(tester, '555');
      await tester.tap(find.byKey(const Key('pin_key_backspace')));
      await tester.tap(find.byKey(const Key('pin_key_backspace')));
      await tester.tap(find.byKey(const Key('pin_key_backspace')));
      await tester.pump();

      // A wrong last digit is removed with backspace
      await typePin(tester, '1234567899');
      await tester.tap(find.byKey(const Key('pin_key_backspace')));
      await tester.pump();
      await submit(tester);

      expect(find.text('Home Screen'), findsOneWidget);
    });
  });

  group('Lock after leaving', () {
    Future<void> unlockedApp(WidgetTester tester, {int? timeout}) async {
      await setAppPin(tester);
      if (timeout != null) {
        await AppLockService.setTimeoutSeconds(timeout);
      }
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      await typePin(tester, '123456789');
      await submit(tester);
      expect(find.text('Home Screen'), findsOneWidget);
    }

    testWidgets('defaults to Immediately', (WidgetTester tester) async {
      expect(await AppLockService.getTimeoutSeconds(), 0);
    });

    testWidgets('closes the app as soon as the user leaves by default', (
      WidgetTester tester,
    ) async {
      await unlockedApp(tester);

      await setLifecycle(tester, AppLifecycleState.paused);

      expect(closedApp(), isTrue);
    });

    testWidgets('waits for the chosen delay before closing', (
      WidgetTester tester,
    ) async {
      await unlockedApp(tester, timeout: 60);

      await setLifecycle(tester, AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 59));
      expect(closedApp(), isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(closedApp(), isTrue);
    });

    testWidgets('does not close if the user comes back in time', (
      WidgetTester tester,
    ) async {
      await unlockedApp(tester, timeout: 60);

      await setLifecycle(tester, AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      await setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 60));

      expect(closedApp(), isFalse);
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('gives screens opened by ClearNet a 5 minute grace period', (
      WidgetTester tester,
    ) async {
      await unlockedApp(tester);

      AppLockService.expectExternalActivity();
      await setLifecycle(tester, AppLifecycleState.paused);
      expect(closedApp(), isFalse);

      await tester.pump(const Duration(minutes: 5, seconds: 1));
      expect(closedApp(), isTrue);
    });

    testWidgets('locks in place if the app was not closed in time', (
      WidgetTester tester,
    ) async {
      // closeApp is mocked here, so the app stays open as if Android had
      // paused the timer; returning should then show the PIN screen
      await unlockedApp(tester);

      await setLifecycle(tester, AppLifecycleState.paused);
      await setLifecycle(tester, AppLifecycleState.resumed);

      expect(find.text('Enter PIN'), findsOneWidget);
      expect(find.text('Home Screen'), findsNothing);
    });

    testWidgets('never closes the app when app lock is off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await setLifecycle(tester, AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 10));

      expect(closedApp(), isFalse);
    });
  });
}
