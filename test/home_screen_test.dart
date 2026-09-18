// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/presentation/screens/home_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen Widget Tests', () {
    final List<MethodCall> methodLog = <MethodCall>[];

    setUp(() {
      methodLog.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, (methodCall) async {
        methodLog.add(methodCall);
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
          '/settings': (context) => const Scaffold(body: Text('Settings Screen')),
        },
        home: const HomeScreen(),
      );
    }

    testWidgets('displays blocking paused initially if no preference set', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Blocking Paused'), findsOneWidget);
      expect(find.text('ClearNet is Idle'), findsOneWidget);
    });

    testWidgets('displays blocking active if preference is true', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'is_blocking_enabled': true,
      });
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Blocking Active'), findsOneWidget);
      expect(find.text('ClearNet is Guarding'), findsOneWidget);
    });

    testWidgets('toggling switch updates preference and calls VPN controller', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'is_blocking_enabled': false});
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify preference updated
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_blocking_enabled'), true);

      // Verify VPN start called
      expect(methodLog.any((c) => c.method == 'startVpn'), true);
      expect(find.text('Blocking Active'), findsOneWidget);

      // Toggle back
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(prefs.getBool('is_blocking_enabled'), false);
      expect(methodLog.any((c) => c.method == 'stopVpn'), true);
    });

    testWidgets('displays stats correctly', (WidgetTester tester) async {
      final today = DateTime.now().toIso8601String().split('T')[0];
      SharedPreferences.setMockInitialValues({
        Constants.blockedWebsitesCountKey: 42,
        Constants.blockedAppsCountKey: 7,
        Constants.lastStatsDateKey: today,
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('Configure Protection button navigates to settings', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        Constants.lockSettingsKey: false,
      });
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Configure Protection');
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Settings Screen'), findsOneWidget);
    });
  });
}
