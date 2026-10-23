// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/data/controllers/uninstall_protection_controller.dart';
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  void mockChannel({bool fail = false}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(Constants.methodChannelName),
          (call) async {
            calls.add(call);
            if (fail) throw PlatformException(code: 'unavailable');
            return true;
          },
        );
  }

  setUp(() {
    calls.clear();
    FlutterSecureStorage.setMockInitialValues({});
    PinService.iterations = 1000;
    mockChannel();
  });

  test('turns protection off when no uninstall PIN is set', () async {
    await UninstallProtectionController.sync();

    expect(calls.single.method, 'setUninstallProtection');
    expect(calls.single.arguments, {'enabled': false});
  });

  test('turns protection on once an uninstall PIN is set', () async {
    await PinService.savePin(Constants.uninstallPinKey, '111111111');

    await UninstallProtectionController.sync();

    expect(calls.single.arguments, {'enabled': true});
  });

  test('the app PIN alone does not turn protection on', () async {
    await PinService.savePin(Constants.appPinKey, '222222222');

    await UninstallProtectionController.sync();

    expect(calls.single.arguments, {'enabled': false});
  });

  test('a failing platform call does not throw', () async {
    mockChannel(fail: true);

    await expectLater(UninstallProtectionController.sync(), completes);
  });

  test('allowProtectedScreens asks Android to allow them', () async {
    await UninstallProtectionController.allowProtectedScreens();

    expect(calls.single.method, 'allowProtectedScreens');
  });
}
