import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'responsive_content.dart';

/// Keeps source offsets intact: hidden delimiters remain zero-width text spans.
/// Selection, undo, clipboard and persistence continue to use the Markdown.
class LiveMarkdownController extends TextEditingController {
  LiveMarkdownController({super.text});

  // TRB: keep the range-aware marker reveal available, but do not expose
  // Markdown syntax in the editor for now.
  static const bool _revealMarkdownAtCursor = false;

  bool _focused = false;
  set focused(bool value) {
    if (_focused == value) return;
    _focused = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Do not hide or reshape an active IME composition.
    if (withComposing &&
        value.isComposingRangeValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: true,
      );
    }
    final spans = <InlineSpan>[];
    final contentWidth =
        math.min(
          MediaQuery.sizeOf(context).width,
          kResponsiveContentMaxWidth,
        ) -
        40;
    var offset = 0;
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final end = offset + line.length;
      final activeLine =
          _focused &&
          selection.isValid &&
          selection.start <= end &&
          (selection.isCollapsed
              ? selection.end >= offset
              : selection.end > offset);
      var lineStyle = style ?? const TextStyle();
      var source = line;
      final heading = RegExp(r'^(#{1,6})\s').firstMatch(line);
      if (heading != null) {
        final level = heading[1]!.length;
        lineStyle = lineStyle.copyWith(
          fontSize: switch (level) {
            1 => 30,
            2 => 25,
            _ => 21,
          },
          fontWeight: FontWeight.w700,
        );
        spans.add(
          markdownDelimiter(
            heading[0]!,
            lineStyle,
            !_revealMarkdownAtCursor || !activeLine,
          ),
        );
        source = line.substring(heading.end);
      }
      if ((!_revealMarkdownAtCursor || !activeLine) &&
          RegExp(r'^\s*---+\s*$').hasMatch(line)) {
        // Render the rule without changing source text or cursor offsets.
        spans.add(
          TextSpan(
            text: line,
            style: lineStyle.copyWith(
              color: Colors.transparent,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.white.withValues(alpha: 0.28),
              decorationThickness: 1,
              // Leave enough safety for the narrower responsive text field:
              // using the full viewport estimate can push the last hidden
              // dash onto a second visual line on web.
              letterSpacing: math.max(0, (contentWidth - 40) / 4),
            ),
          ),
        );
      } else {
        spans.addAll(
          markdownInlineSpans(
            source,
            lineStyle,
            revealRange:
                _revealMarkdownAtCursor && _focused && selection.isValid
                ? selection
                : null,
            sourceOffset: offset + (heading?.end ?? 0),
          ),
        );
      }
      if (i < lines.length - 1) {
        final collapsesDividerSpacing =
            line.isEmpty &&
            ((i > 0 && RegExp(r'^\s*---+\s*$').hasMatch(lines[i - 1])) ||
                (i + 1 < lines.length &&
                    RegExp(r'^\s*---+\s*$').hasMatch(lines[i + 1])));
        spans.add(
          TextSpan(
            text: '\n',
            style: collapsesDividerSpacing
                ? (style ?? const TextStyle()).copyWith(
                    fontSize: 0,
                    height: 0,
                  )
                : style,
          ),
        );
      }
      offset = end + 1;
    }
    return TextSpan(style: style, children: spans);
  }
}

TextSpan markdownDelimiter(String text, TextStyle style, bool hidden) =>
    TextSpan(
      text: text,
      style: hidden
          ? style.copyWith(
              fontSize: 0,
              height: 0,
              letterSpacing: 0,
              wordSpacing: 0,
              color: Colors.transparent,
            )
          : style.copyWith(color: style.color?.withValues(alpha: 0.55)),
    );

/// Inline formatting shared by the editor and the underline Markdown extension.
List<InlineSpan> markdownInlineSpans(
  String text,
  TextStyle style, {
  bool hideMarkers = true,
  bool preserveMarkers = true,
  TextRange? revealRange,
  int sourceOffset = 0,
}) {
  final patterns = <(RegExp, int, int, TextStyle)>[
    (
      RegExp(r'\*\*(.+?)\*\*'),
      2,
      2,
      style.copyWith(
        fontWeight: FontWeight.bold,
        fontVariations: const [FontVariation('wght', 700)],
      ),
    ),
    (
      RegExp(r'__(.+?)__'),
      2,
      2,
      style.copyWith(
        fontWeight: FontWeight.bold,
        fontVariations: const [FontVariation('wght', 700)],
      ),
    ),
    (
      RegExp(r'<u>(.+?)</u>'),
      3,
      4,
      style.copyWith(
        decoration: TextDecoration.combine([
          if (style.decoration != null) style.decoration!,
          TextDecoration.underline,
        ]),
      ),
    ),
    (
      RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'),
      1,
      1,
      style.copyWith(fontStyle: FontStyle.italic),
    ),
    (
      RegExp(r'(?<!_)_(?!_)(.+?)(?<!_)_(?!_)'),
      1,
      1,
      style.copyWith(fontStyle: FontStyle.italic),
    ),
    (
      RegExp(r'~~(.+?)~~'),
      2,
      2,
      style.copyWith(decoration: TextDecoration.lineThrough),
    ),
    (RegExp(r'`([^`]+)`'), 1, 1, style.copyWith(fontFamily: 'monospace')),
  ];
  RegExpMatch? first;
  (RegExp, int, int, TextStyle)? selected;
  for (final pattern in patterns) {
    final match = pattern.$1.firstMatch(text);
    if (match != null && (first == null || match.start < first.start)) {
      first = match;
      selected = pattern;
    }
  }
  if (first == null || selected == null) {
    return [TextSpan(text: text, style: style)];
  }
  final start = first.start;
  final end = first.end;
  final absoluteStart = sourceOffset + start;
  final absoluteEnd = sourceOffset + end;
  final revealThis = revealRange != null &&
      (revealRange.isCollapsed
          ? revealRange.start >= absoluteStart &&
              revealRange.start <= absoluteEnd
          : revealRange.start < absoluteEnd && revealRange.end > absoluteStart);
  return [
    if (start > 0) TextSpan(text: text.substring(0, start), style: style),
    if (preserveMarkers)
      markdownDelimiter(
        text.substring(start, start + selected.$2),
        style,
        hideMarkers && !revealThis,
      ),
    ...markdownInlineSpans(
      text.substring(start + selected.$2, end - selected.$3),
      selected.$4,
      hideMarkers: hideMarkers,
      preserveMarkers: preserveMarkers,
      revealRange: revealRange,
      sourceOffset: sourceOffset + start + selected.$2,
    ),
    if (preserveMarkers)
      markdownDelimiter(
        text.substring(end - selected.$3, end),
        style,
        hideMarkers && !revealThis,
      ),
    ...markdownInlineSpans(
      text.substring(end),
      style,
      hideMarkers: hideMarkers,
      preserveMarkers: preserveMarkers,
      revealRange: revealRange,
      sourceOffset: sourceOffset + end,
    ),
  ];
}
