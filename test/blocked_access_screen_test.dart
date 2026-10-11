// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/presentation/screens/blocked_access_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlockedAccessScreen Widget Tests', () {
    final List<MethodCall> methodLog = <MethodCall>[];

    setUp(() {
      methodLog.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(Constants.methodChannelName),
            (MethodCall methodCall) async {
              methodLog.add(methodCall);
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
      return const MaterialApp(home: BlockedAccessScreen());
    }

    testWidgets('displays blocked website message correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Sorry, this website is blocked.'), findsOneWidget);
      expect(
        find.textContaining('${Constants.appName} has restricted access'),
        findsOneWidget,
      );
      expect(find.text('Okay'), findsOneWidget);
    });

    testWidgets('tapping Okay button invokes goHome method channel call', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final okayButton = find.widgetWithText(ElevatedButton, 'Okay');
      expect(okayButton, findsOneWidget);

      await tester.tap(okayButton);
      await tester.pumpAndSettle();

      expect(methodLog.any((call) => call.method == 'goHome'), isTrue);
    });
  });
}
