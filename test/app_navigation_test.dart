// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/main.dart';
import 'package:clearnet/shared/utilities/constants.dart';

/// Tests the screens Android opens inside the running app: the blocked page
/// and the uninstall PIN screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PinService.iterations = 1000;
    calls.clear();
    PackageInfo.setMockInitialValues(
      appName: Constants.appName,
      packageName: 'com.example.clearnet',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    // Tours already seen, so they don't cover the screens under test
    final prefs = SharedPreferencesAsync();
    for (final key in [
      AppTourManager.protectionTourKey,
      AppTourManager.contentTourKey,
      AppTourManager.settingsTourKey,
      AppTourManager.blockedAppsTourKey,
      AppTourManager.guideTourKey,
    ]) {
      await prefs.setBool(key, true);
    }

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => '.',
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel(Constants.methodChannelName),
      (call) async {
        calls.add(call);
        switch (call.method) {
          case 'isAccessibilityServiceEnabled':
          case 'isIgnoringBatteryOptimizations':
            return true;
          default:
            return null;
        }
      },
    );
  });

  /// Sends a method call from the Android side to the app.
  Future<void> sendFromAndroid(WidgetTester tester, String method) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      Constants.methodChannelName,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(const ClearNetApp());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  bool called(String method) => calls.any((call) => call.method == method);

  testWidgets('a block event shows the blocked page over the main screen', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    await sendFromAndroid(tester, 'showBlockedPage');
    expect(find.text('Sorry, this website is blocked.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Okay'));
    await tester.pumpAndSettle();

    expect(find.text('Sorry, this website is blocked.'), findsNothing);
    expect(find.text('Blocking paused'), findsOneWidget);
    expect(called('goHome'), isTrue);
  });

  testWidgets('repeated block events do not stack blocked pages', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    await sendFromAndroid(tester, 'showBlockedPage');
    await sendFromAndroid(tester, 'showBlockedPage');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Okay'));
    await tester.pumpAndSettle();

    expect(find.text('Sorry, this website is blocked.'), findsNothing);
  });

  testWidgets('a request to remove ClearNet asks for the uninstall PIN', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(
      () => PinService.savePin(Constants.uninstallPinKey, '111111111'),
    );
    await startApp(tester);

    await sendFromAndroid(tester, 'showUninstallPin');

    expect(find.text('Enter Uninstall PIN'), findsOneWidget);
  });

  testWidgets('with no uninstall PIN, that request just closes the app', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      Constants.methodChannelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('showUninstallPin'),
      ),
      (_) {},
    );
    // The screen shows a spinner until the app closes, so don't wait to settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(called('closeApp'), isTrue);
    expect(find.text('Enter Uninstall PIN'), findsNothing);
  });
}
