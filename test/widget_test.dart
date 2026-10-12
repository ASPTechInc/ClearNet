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
import 'package:clearnet/main.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inMemoryStore = InMemorySharedPreferencesAsync.empty();
  SharedPreferencesAsyncPlatform.instance = inMemoryStore;
  bool isAccessibilityEnabled = true;
  bool isIgnoringBatteryOptimisation = true;

  setUp(() async {
    await SharedPreferencesAsync().clear();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    isAccessibilityEnabled = true;
    isIgnoringBatteryOptimisation = true;
    PackageInfo.setMockInitialValues(
      appName: Constants.appName,
      packageName: 'com.example.clearnet',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    // Mock Path Provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return '.';
          },
        );

    // Mock Main Method Channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(Constants.methodChannelName),
          (MethodCall methodCall) async {
            if (methodCall.method == 'isAccessibilityServiceEnabled') {
              return isAccessibilityEnabled;
            }
            if (methodCall.method == 'isIgnoringBatteryOptimizations') {
              return isIgnoringBatteryOptimisation;
            }
            if (methodCall.method == 'checkInitialAction') {
              return null;
            }
            return null;
          },
        );
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ClearNetApp());

    // Allow initialisations to complete
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify that the app starts. It should land on ProtectionScreen which has
    // the app name in the AppBar.
    expect(find.text(Constants.appName), findsOneWidget);

    // Clear pending timers to avoid test failure
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'starts tour after accessibility dialog closes when battery is already enabled',
    (WidgetTester tester) async {
      isAccessibilityEnabled = false;
      isIgnoringBatteryOptimisation = true;

      await tester.pumpWidget(const ClearNetApp());
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Action required'), findsOneWidget);

      await tester.tap(find.text('Enable service'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      isAccessibilityEnabled = true;
      await tester.tap(find.text('Confirm enabling'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final prefs = SharedPreferencesAsync();
      expect(
        await prefs.getBool(AppTourManager.protectionTourKey),
        isTrue,
      );
    },
  );

  testWidgets(
    'starts tour after battery dialog closes when accessibility is already enabled',
    (WidgetTester tester) async {
      isAccessibilityEnabled = true;
      isIgnoringBatteryOptimisation = false;

      await tester.pumpWidget(const ClearNetApp());
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Battery performance'), findsOneWidget);

      await tester.tap(find.text('Disable optimisation'));
      await tester.pumpAndSettle();

      isIgnoringBatteryOptimisation = true;
      await tester.tap(find.text('Confirm disabling'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final prefs = SharedPreferencesAsync();
      expect(
        await prefs.getBool(AppTourManager.protectionTourKey),
        isTrue,
      );
    },
  );

  testWidgets('replay app tour restarts tour from settings', (
    WidgetTester tester,
  ) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool('has_seen_app_tour', true);
    await prefs.setBool(AppTourManager.protectionTourKey, true);
    await prefs.setBool(AppTourManager.contentTourKey, true);
    await prefs.setBool(AppTourManager.settingsTourKey, true);

    await tester.pumpWidget(const ClearNetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final replayTourFinder = find.widgetWithText(ListTile, 'Replay app tour');
    await tester.scrollUntilVisible(
      replayTourFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(replayTourFinder);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Blocking paused'), findsOneWidget);
    expect(
      await prefs.getBool(AppTourManager.protectionTourKey),
      isTrue,
    );
  });
}
