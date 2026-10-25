// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:io';

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
import 'package:clearnet/data/services/app_lock_service.dart';
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/presentation/screens/settings_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  late Directory tempDir;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PinService.iterations = 1000;
    calls.clear();
    tempDir = Directory.systemTemp.createTempSync('clearnet_settings_');
    PackageInfo.setMockInitialValues(
      appName: Constants.appName,
      packageName: 'com.example.clearnet',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tempDir.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel(Constants.methodChannelName),
      (call) async {
        calls.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Opens Settings and scrolls to [target]. Tiles in the About section need
  /// [inAbout], because that section starts collapsed.
  Future<void> showSettingsAt(
    WidgetTester tester,
    Finder target, {
    bool inAbout = false,
  }) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    if (inAbout) {
      final about = find.text('About');
      await tester.scrollUntilVisible(
        about,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(about);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      target,
      200.0,
      // The page itself; some tiles contain their scrollable fields
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseDnsServer(WidgetTester tester, String label) async {
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await showSettingsAt(tester, dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  int vpnStarts() => calls.where((call) => call.method == 'startVpn').length;

  group('DNS server', () {
    testWidgets('a new server is applied to the running VPN', (
      WidgetTester tester,
    ) async {
      await SharedPreferencesAsync().setBool('is_blocking_enabled', true);

      await chooseDnsServer(tester, 'Quad9 (9.9.9.9)');

      expect(await SharedPreferencesAsync().getString('custom_dns'), '9.9.9.9');
      expect(vpnStarts(), 1);
    });

    testWidgets('the VPN is not started while blocking is paused', (
      WidgetTester tester,
    ) async {
      await chooseDnsServer(tester, 'Quad9 (9.9.9.9)');

      expect(await SharedPreferencesAsync().getString('custom_dns'), '9.9.9.9');
      expect(vpnStarts(), 0);
    });

    testWidgets('choosing the default servers clears the custom one', (
      WidgetTester tester,
    ) async {
      await SharedPreferencesAsync().setString('custom_dns', '9.9.9.9');

      await chooseDnsServer(tester, 'Default (UncensoredDNS, AdGuard, Quad9)');

      expect(await SharedPreferencesAsync().getString('custom_dns'), isNull);
    });
  });

  group('Lock after leaving', () {
    final tile = find.text('Lock after leaving');

    testWidgets('is hidden while app lock is off', (WidgetTester tester) async {
      await showSettingsAt(
        tester,
        find.widgetWithText(SwitchListTile, 'Set app PIN'),
      );

      expect(tile, findsNothing);
    });

    testWidgets('shows Immediately and saves a new choice', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(
        () => PinService.savePin(Constants.appPinKey, '123456789'),
      );
      await const FlutterSecureStorage().write(
        key: Constants.appLockEnabledKey,
        value: 'true',
      );
      await showSettingsAt(tester, tile);

      expect(find.text('Immediately'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 minutes').last);
      await tester.pumpAndSettle();

      expect(await AppLockService.getTimeoutSeconds(), 300);
      expect(find.text('5 minutes'), findsOneWidget);
    });
  });

  testWidgets('Open-source licences opens the licences page', (
    WidgetTester tester,
  ) async {
    final tile = find.text('Open-source licences');
    await showSettingsAt(tester, tile, inAbout: true);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('the changelog shows bullets that continue onto a second line', (
    WidgetTester tester,
  ) async {
    final tile = find.text('Changelog');
    await showSettingsAt(tester, tile, inAbout: true);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cannot be uninstalled without the PIN.'),
      findsOneWidget,
    );
  });

  testWidgets('the privacy policy dialogue does not repeat its title', (
    WidgetTester tester,
  ) async {
    final tile = find.text('Privacy policy');
    await showSettingsAt(tester, tile, inAbout: true);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    // Only the dialogue title, not the file's own "# Privacy policy"
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Privacy policy'),
      ),
      findsOneWidget,
    );
    expect(find.text('Summary'), findsOneWidget);
  });
}
