// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/presentation/screens/protection_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inMemoryStore = InMemorySharedPreferencesAsync.empty();
  SharedPreferencesAsyncPlatform.instance = inMemoryStore;

  group('ProtectionScreen Widget Tests', () {
    final List<MethodCall> methodLog = <MethodCall>[];
    Map<String, dynamic> mockStats = {};

    setUp(() async {
      await SharedPreferencesAsync().clear();
      await SharedPreferencesAsync().setBool('has_seen_app_tour', true);
      methodLog.clear();
      mockStats.clear();
      AppTourManager.initialiseAppTour();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, (methodCall) async {
            methodLog.add(methodCall);
            if (methodCall.method == 'isAccessibilityServiceEnabled') {
              return true;
            }
            if (methodCall.method == 'isIgnoringBatteryOptimizations') {
              return true;
            }
            if (methodCall.method == 'showDisableConfirmation') return true;
            if (methodCall.method == 'getStats') return mockStats;
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, null);
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        routes: {
          '/settings': (context) =>
              const Scaffold(body: Text('Settings Screen')),
        },
        home: const ProtectionScreen(),
      );
    }

    testWidgets('displays blocking paused initially if no preference set', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Blocking paused'), findsOneWidget);
      expect(find.text('ClearNet is idle'), findsOneWidget);
    });

    testWidgets('displays blocking active if preference is true', (
      WidgetTester tester,
    ) async {
      await SharedPreferencesAsync().setBool('is_blocking_enabled', true);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Blocking active'), findsOneWidget);
      expect(find.text('ClearNet is guarding'), findsOneWidget);
    });

    testWidgets('toggling switch updates preference and calls VPN controller', (
      WidgetTester tester,
    ) async {
      await SharedPreferencesAsync().setBool('is_blocking_enabled', false);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify VPN start called
      expect(methodLog.any((c) => c.method == 'startVpn'), true);
      expect(find.text('Blocking active'), findsOneWidget);

      // Toggle back
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(methodLog.any((c) => c.method == 'stopVpn'), true);
    });

    testWidgets('displays stats correctly', (WidgetTester tester) async {
      mockStats = {
        Constants.blockedWebsitesCountKey: 42,
        Constants.blockedAppsCountKey: 7,
      };

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text("Today's activity"), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });
  });
}
