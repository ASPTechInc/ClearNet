// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/app_lock_service.dart';
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
    PinService.iterations = 1000;
    AppLockService.resetExpectation();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(Constants.methodChannelName),
          (_) async => null,
        );
  });

  Future<void> turnOnAppLock() async {
    await PinService.savePin(Constants.appPinKey, '123456789');
    await const FlutterSecureStorage().write(
      key: Constants.appLockEnabledKey,
      value: 'true',
    );
  }

  group('Lock delay setting', () {
    test('defaults to Immediately', () async {
      expect(await AppLockService.getTimeoutSeconds(), 0);
    });

    test('saves each offered option', () async {
      for (final seconds in AppLockService.timeoutOptions.keys) {
        await AppLockService.setTimeoutSeconds(seconds);
        expect(await AppLockService.getTimeoutSeconds(), seconds);
      }
    });

    test('ignores a saved value that is not one of the options', () async {
      await SharedPreferencesAsync().setInt(Constants.appLockTimeoutKey, 42);
      expect(await AppLockService.getTimeoutSeconds(), 0);
    });

    test('offers Immediately, 1 minute and 5 minutes', () {
      expect(AppLockService.timeoutOptions, {
        0: 'Immediately',
        60: '1 minute',
        300: '5 minutes',
      });
    });
  });

  group('Is app lock on', () {
    test('is off by default', () async {
      expect(await AppLockService.isLockEnabled(), isFalse);
    });

    test('is off if the switch is on but no PIN is saved', () async {
      await const FlutterSecureStorage().write(
        key: Constants.appLockEnabledKey,
        value: 'true',
      );
      expect(await AppLockService.isLockEnabled(), isFalse);
    });

    test('is on with a PIN and the switch on', () async {
      await turnOnAppLock();
      expect(await AppLockService.isLockEnabled(), isTrue);
    });
  });

  group('Delay after leaving', () {
    test('is null when app lock is off', () async {
      expect(await AppLockService.delayAfterLeaving(), isNull);
    });

    test('is the chosen delay when app lock is on', () async {
      await turnOnAppLock();
      await AppLockService.setTimeoutSeconds(60);
      expect(
        await AppLockService.delayAfterLeaving(),
        const Duration(minutes: 1),
      );
    });

    test('is the grace period after ClearNet opens another screen', () async {
      await turnOnAppLock();
      AppLockService.expectExternalActivity();
      expect(
        await AppLockService.delayAfterLeaving(),
        AppLockService.externalActivityGrace,
      );
    });

    test('keeps a longer chosen delay over the grace period', () async {
      await turnOnAppLock();
      await AppLockService.setTimeoutSeconds(300);
      AppLockService.expectExternalActivity();
      expect(
        await AppLockService.delayAfterLeaving(),
        const Duration(minutes: 5),
      );
    });

    test('only gives the grace period once', () async {
      await turnOnAppLock();
      AppLockService.expectExternalActivity();
      await AppLockService.delayAfterLeaving();
      expect(await AppLockService.delayAfterLeaving(), Duration.zero);
    });
  });

  group('Screens ClearNet opens get the grace period', () {
    final opensScreen = <String, Future<void> Function()>{
      'startVpn': VpnController.startVpn,
      'openAccessibilitySettings': VpnController.openAccessibilitySettings,
      'requestIgnoreBatteryOptimisations':
          VpnController.requestIgnoreBatteryOptimisations,
    };

    for (final entry in opensScreen.entries) {
      test(entry.key, () async {
        await turnOnAppLock();
        await entry.value();
        expect(
          await AppLockService.delayAfterLeaving(),
          AppLockService.externalActivityGrace,
        );
      });
    }
  });
}
