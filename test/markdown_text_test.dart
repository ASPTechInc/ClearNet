// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/presentation/widgets/markdown_text.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    String markdown, {
    bool skipTitle = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownText(markdown, skipTitle: skipTitle),
        ),
      ),
    ),
  );

  /// The style of the span whose text is exactly [text].
  TextStyle? styleOf(WidgetTester tester, String text) {
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      TextStyle? found;
      void visit(InlineSpan span, TextStyle? inherited) {
        if (span is! TextSpan) return;
        final style = inherited?.merge(span.style) ?? span.style;
        if (span.text == text) found = style;
        span.children?.forEach((child) => visit(child, style));
      }

      visit(rich.text, null);
      if (found != null) return found;
    }
    return null;
  }

  testWidgets('leaves out the title when asked', (WidgetTester tester) async {
    await show(tester, '# Privacy policy\n\nHello', skipTitle: true);

    expect(find.text('Privacy policy'), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('keeps the title by default', (WidgetTester tester) async {
    await show(tester, '# Privacy policy');
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('headings are bold and get smaller at each level', (
    WidgetTester tester,
  ) async {
    await show(tester, '# One\n## Two\n### Three');

    final one = styleOf(tester, 'One')!;
    final two = styleOf(tester, 'Two')!;
    final three = styleOf(tester, 'Three')!;
    for (final style in [one, two, three]) {
      expect(style.fontWeight, FontWeight.bold);
    }
    expect(one.fontSize!, greaterThan(two.fontSize!));
    expect(two.fontSize!, greaterThan(three.fontSize!));
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('bullets get a circle in the primary colour', (
    WidgetTester tester,
  ) async {
    await show(tester, '- First\n- Second');

    expect(find.byType(MarkdownBullet), findsNWidgets(2));
    expect(find.text('First'), findsOneWidget);
    expect(find.textContaining('- '), findsNothing);
    final dot = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(MarkdownBullet).first,
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = dot.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(
      decoration.color,
      Theme.of(
        tester.element(find.byType(MarkdownBullet).first),
      ).colorScheme.primary,
    );
  });

  testWidgets('text between double asterisks is bold', (
    WidgetTester tester,
  ) async {
    await show(tester, '- **VPN service:** filters DNS');

    expect(styleOf(tester, 'VPN service:')?.fontWeight, FontWeight.bold);
    expect(styleOf(tester, ' filters DNS')?.fontWeight, isNot(FontWeight.bold));
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('code is shown without backticks in a monospace font', (
    WidgetTester tester,
  ) async {
    await show(tester, 'Uses `shared_preferences` here');

    expect(styleOf(tester, 'shared_preferences')?.fontFamily, 'monospace');
    expect(find.textContaining('`'), findsNothing);
  });

  testWidgets('an indented line continues the bullet above it', (
    WidgetTester tester,
  ) async {
    await show(tester, '- Starts here\n  and ends here.\n- Next');

    expect(find.byType(MarkdownBullet), findsNWidgets(2));
    expect(find.text('Starts here and ends here.'), findsOneWidget);
  });

  testWidgets('lines next to each other form one paragraph', (
    WidgetTester tester,
  ) async {
    await show(tester, 'First line\nsecond line\n\nNew paragraph');

    expect(find.text('First line second line'), findsOneWidget);
    expect(find.text('New paragraph'), findsOneWidget);
  });

  testWidgets('the privacy policy shows without any Markdown symbols', (
    WidgetTester tester,
  ) async {
    final policy = File('PRIVACY_POLICY.md').readAsStringSync();
    await show(tester, policy, skipTitle: true);

    expect(find.text('Privacy policy'), findsNothing);
    expect(styleOf(tester, 'Summary')?.fontWeight, FontWeight.bold);
    expect(find.byType(MarkdownBullet), findsWidgets);
    for (final symbol in ['**', '`', '## ']) {
      expect(find.textContaining(symbol), findsNothing, reason: symbol);
    }
  });
}
