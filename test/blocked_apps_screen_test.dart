// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/presentation/screens/blocked_apps_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inMemoryStore = InMemorySharedPreferencesAsync.empty();
  SharedPreferencesAsyncPlatform.instance = inMemoryStore;

  group('BlockedAppsScreen Widget & Interaction Tests', () {
    final fakeApps = [
      {'name': 'Camera App', 'packageName': 'com.android.camera'},
      {'name': 'Social App', 'packageName': 'com.social.media'},
      {'name': 'Game App', 'packageName': 'com.gaming.fun'},
    ];

    setUp(() async {
      await SharedPreferencesAsync().clear();
      SharedPreferences.setMockInitialValues({});

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(Constants.methodChannelName),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getInstalledApps') {
                return fakeApps;
              }
              return null;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(Constants.methodChannelName),
            null,
          );
    });

    Widget createWidgetUnderTest() {
      return const MaterialApp(home: BlockedAppsScreen());
    }

    testWidgets('renders list of installed apps correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Blocked apps'), findsOneWidget);
      expect(find.text('Camera App'), findsOneWidget);
      expect(find.text('Social App'), findsOneWidget);
      expect(find.text('Game App'), findsOneWidget);
    });

    testWidgets('filters apps based on search query', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Social');
      await tester.pumpAndSettle();

      expect(find.text('Social App'), findsOneWidget);
      expect(find.text('Camera App'), findsNothing);
      expect(find.text('Game App'), findsNothing);
    });

    testWidgets('toggling switch blocks and unblocks an app', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final cameraSwitch = find.widgetWithText(SwitchListTile, 'Camera App');
      expect(cameraSwitch, findsOneWidget);

      // Tap to block Camera App
      await tester.tap(cameraSwitch);
      await tester.pumpAndSettle();

      List<String>? blocked = await SharedPreferencesAsync().getStringList(
        Constants.blockedAppsKey,
      );
      expect(blocked, contains('com.android.camera'));

      // Tap again to unblock
      await tester.tap(cameraSwitch);
      await tester.pumpAndSettle();

      blocked = await SharedPreferencesAsync().getStringList(
        Constants.blockedAppsKey,
      );
      expect(blocked, isNot(contains('com.android.camera')));
    });
  });
}
