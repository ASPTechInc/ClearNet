// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

/// Types [pin] on the number pad and taps the tick, then waits for PIN
/// hashing, which runs in a real isolate that the test's fake clock doesn't
/// wait for.
Future<void> enterPinOnPad(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.byKey(Key('pin_key_$digit')));
  }
  await tester.pump();
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const Key('pin_key_enter')));
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
}
