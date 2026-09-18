// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// Flutter imports:

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    
    // Allow BiometricLockScreen to complete its async check
    await tester.pump(); 
    await tester.pumpAndSettle();

    // Verify that the app starts. It should land on HomeScreen which has 
    // the app name in the AppBar, or PinLockScreen if a PIN is set.
    final homeFound = find.text('ClearNet').evaluate().isNotEmpty;
    final pinFound = find.text('Enter PIN').evaluate().isNotEmpty;
    
    expect(homeFound || pinFound, isTrue, 
        reason: 'App should start at either HomeScreen ("ClearNet") or PinLockScreen ("Enter PIN")');
  });
}
