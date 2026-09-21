// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// Flutter imports:

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/main.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'ClearNet',
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
              return true; // Prevent Accessibility Dialog from showing
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

    // Allow initializations to complete
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify that the app starts. It should land on HomeScreen which has
    // the app name in the AppBar.
    expect(find.text('ClearNet'), findsOneWidget);

    // Clear pending timers to avoid test failure
    await tester.pump(const Duration(seconds: 2));
  });
}
