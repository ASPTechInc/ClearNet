// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';

/// Shows a simple Markdown document, such as PRIVACY_POLICY.md, in the app's
/// style. Supports `#` to `###` headings, `-` bullets, paragraphs, **bold**
/// and `code`. Lines next to each other are joined into one paragraph.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.markdown, {super.key, this.skipTitle = false});

  final String markdown;

  /// Leaves out the first `#` heading, for when a dialogue already shows it.
  final bool skipTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.4,
    );
    // Each heading level is bold and a step smaller than the one above
    final headingStyles = {
      1: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      2: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      3: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    };

    final children = <Widget>[];
    final paragraph = <String>[];
    // The bullet being read; indented lines after it continue it
    String? bullet;
    var titleSkipped = !skipTitle;

    void endBlock() {
      if (bullet != null) {
        children.add(
          MarkdownBullet(
            child: Text.rich(
              TextSpan(style: bodyStyle, children: inlineSpans(bullet!)),
            ),
          ),
        );
        bullet = null;
      }
      if (paragraph.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text.rich(
              TextSpan(
                style: bodyStyle,
                children: inlineSpans(paragraph.join(' ')),
              ),
            ),
          ),
        );
        paragraph.clear();
      }
    }

    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trim();
      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);

      if (line.isEmpty) {
        endBlock();
      } else if (heading != null) {
        endBlock();
        final level = heading.group(1)!.length;
        if (level == 1 && !titleSkipped) {
          titleSkipped = true;
          continue;
        }
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 8, bottom: 8),
            child: Text.rich(
              TextSpan(
                style: headingStyles[level],
                children: inlineSpans(heading.group(2)!),
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        endBlock();
        bullet = line.substring(2).trim();
      } else if (bullet != null && rawLine.startsWith(' ')) {
        bullet = '$bullet $line';
      } else {
        if (bullet != null) endBlock();
        paragraph.add(line);
      }
    }
    endBlock();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// Splits [text] into plain, **bold** and `code` spans.
  static List<InlineSpan> inlineSpans(String text) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    var start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        );
      }
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return spans;
  }
}

/// A bullet point: a small circle in the theme's primary colour, then [child].
class MarkdownBullet extends StatelessWidget {
  const MarkdownBullet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 12.0),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
