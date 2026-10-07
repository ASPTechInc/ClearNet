// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/screens/app_lock_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inMemoryStore = InMemorySharedPreferencesAsync.empty();
  SharedPreferencesAsyncPlatform.instance = inMemoryStore;

  group('AppLockScreen Tests', () {
    setUp(() async {
      await SharedPreferencesAsync().clear();
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        routes: {
          AppRoutes.home: (context) => const Scaffold(body: Text('Home Screen')),
        },
        home: const AppLockScreen(),
      );
    }

    testWidgets(
      'redirects directly to Home if App Lock is not enabled or no PIN set',
      (WidgetTester tester) async {
        FlutterSecureStorage.setMockInitialValues({});

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Home Screen'), findsOneWidget);
      },
    );

    testWidgets('shows PinLockScreen if App PIN set and App Lock enabled', (
      WidgetTester tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({
        Constants.appLockEnabledKey: 'true',
        Constants.appPinKey: '1234',
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Enter App PIN'), findsOneWidget);

      // Enter correct PIN
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
    });
  });
}
