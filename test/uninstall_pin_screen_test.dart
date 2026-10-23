// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/presentation/screens/uninstall_pin_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<MethodCall> systemCalls = <MethodCall>[];

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    PinService.iterations = 1000;
    systemCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(Constants.methodChannelName),
          (call) async {
            systemCalls.add(call);
            return null;
          },
        );
  });

  bool closed() => systemCalls.any((call) => call.method == 'closeApp');

  /// Taps Submit and waits for PIN hashing, which runs in a real isolate.
  Future<void> submit(WidgetTester tester, String pin) async {
    await tester.enterText(find.byType(TextField), pin);
    await tester.runAsync(() async {
      await tester.tap(find.byType(ElevatedButton));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
  }

  Future<void> savePins(WidgetTester tester) => tester.runAsync(() async {
    await PinService.savePin(Constants.uninstallPinKey, '111111111');
    await PinService.savePin(Constants.appPinKey, '222222222');
  });

  testWidgets('asks for the uninstall PIN and closes when it is correct', (
    WidgetTester tester,
  ) async {
    await savePins(tester);
    await tester.pumpWidget(const MaterialApp(home: UninstallPinScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Enter Uninstall PIN'), findsOneWidget);
    await submit(tester, '111111111');

    expect(closed(), isTrue);
    // The protected system screens are allowed before the app closes
    final methods = systemCalls.map((call) => call.method).toList();
    expect(methods, containsAllInOrder(['allowProtectedScreens', 'closeApp']));
  });

  testWidgets('Back does not leave the screen', (WidgetTester tester) async {
    await savePins(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Text('Main screen')),
        routes: {'/pin': (_) => const UninstallPinScreen()},
        initialRoute: '/pin',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter Uninstall PIN'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Enter Uninstall PIN'), findsOneWidget);
  });

  testWidgets('does not accept the app PIN', (WidgetTester tester) async {
    await savePins(tester);
    await tester.pumpWidget(const MaterialApp(home: UninstallPinScreen()));
    await tester.pumpAndSettle();

    await submit(tester, '222222222');

    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(closed(), isFalse);
    expect(
      systemCalls.any((call) => call.method == 'allowProtectedScreens'),
      isFalse,
    );
  });

  testWidgets('closes straight away if no uninstall PIN is set', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UninstallPinScreen()));
    // The loading spinner keeps animating, since nothing really closes here
    await tester.pump();
    await tester.pump();

    expect(closed(), isTrue);
    expect(find.text('Enter Uninstall PIN'), findsNothing);
  });
}
