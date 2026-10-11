// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/main.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inMemoryStore = InMemorySharedPreferencesAsync.empty();
  SharedPreferencesAsyncPlatform.instance = inMemoryStore;

  setUp(() async {
    await SharedPreferencesAsync().clear();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
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
              return true; // Prevent Accessibility Dialogue from showing
            }
            if (methodCall.method == 'isIgnoringBatteryOptimizations') {
              return true; // Prevent Battery Optimisation Dialogue from showing
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
}
