// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/presentation/widgets/disable_confirmation_dialogue.dart';

/// The sentence currently shown: the only text in the dialogue with many words.
String shownSentence(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(DisableConfirmationDialogue),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data ?? '')
    .firstWhere((text) => text.split(' ').length >= 12);

/// Opens the dialogue and returns a holder for its result.
Future<List<bool?>> openDialogue(WidgetTester tester) async {
  final result = <bool?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result.add(
              await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const DisableConfirmationDialogue(),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return result;
}

Future<void> typeAndContinue(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows step 1 of 3 with a sentence of 12 to 15 words', (
    WidgetTester tester,
  ) async {
    await openDialogue(tester);

    expect(find.text('Step 1 of 3'), findsOneWidget);
    final words = shownSentence(tester).split(' ');
    expect(words.length, inInclusiveRange(12, 15));
  });

  testWidgets('no word appears twice across the three sentences', (
    WidgetTester tester,
  ) async {
    await openDialogue(tester);

    final words = <String>[];
    for (var step = 1; step <= 3; step++) {
      final sentence = shownSentence(tester);
      words.addAll(sentence.split(' '));
      if (step < 3) await typeAndContinue(tester, sentence);
    }
    expect(words.toSet().length, words.length, reason: words.join(' '));
  });

  testWidgets('typing all three sentences exactly closes it with true', (
    WidgetTester tester,
  ) async {
    final result = await openDialogue(tester);

    for (var step = 1; step <= 3; step++) {
      expect(find.text('Step $step of 3'), findsOneWidget);
      await typeAndContinue(tester, shownSentence(tester));
    }

    expect(find.byType(DisableConfirmationDialogue), findsNothing);
    expect(result, [true]);
  });

  testWidgets('a mistake starts again with new sentences', (
    WidgetTester tester,
  ) async {
    final result = await openDialogue(tester);
    final first = shownSentence(tester);

    await typeAndContinue(tester, first);
    await typeAndContinue(tester, 'not the sentence');
    await typeAndContinue(tester, shownSentence(tester));

    expect(find.byType(DisableConfirmationDialogue), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.textContaining('Starting over'), findsOneWidget);
    expect(result, isEmpty);
  });

  testWidgets('a blank entry is explained inside the dialogue', (
    WidgetTester tester,
  ) async {
    await openDialogue(tester);

    await typeAndContinue(tester, '   ');

    expect(find.text('Type the words before continuing.'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('I give up closes it with false', (WidgetTester tester) async {
    final result = await openDialogue(tester);

    await tester.tap(find.text('I give up'));
    await tester.pumpAndSettle();

    expect(result, [false]);
  });

  testWidgets('Back does not close it', (WidgetTester tester) async {
    final result = await openDialogue(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(DisableConfirmationDialogue), findsOneWidget);
    expect(result, isEmpty);
  });

  testWidgets(
    'the sentence cannot be copied and the box cannot be pasted into',
    (WidgetTester tester) async {
      await openDialogue(tester);

      expect(
        find.descendant(
          of: find.byType(DisableConfirmationDialogue),
          matching: find.byType(SelectableText),
        ),
        findsNothing,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enableInteractiveSelection, isFalse);
      expect(field.autocorrect, isFalse);
    },
  );
}
