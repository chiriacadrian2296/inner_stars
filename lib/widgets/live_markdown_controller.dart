import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/services.dart';

import '../utils/markdown_editing.dart';

import 'responsive_content.dart';

// Zero-sized trailing spaces trigger Flutter's end-of-text caret assertion.
// Keep invisible delimiters measurable without visibly indenting the content.
const double kHiddenMarkdownFontSize = 0.1;

/// Keeps source offsets intact: hidden delimiters retain negligible text metrics.
/// Selection, undo, clipboard and persistence continue to use the Markdown.
class LiveMarkdownController extends TextEditingController {
  LiveMarkdownController({super.text, this.maxSourceLength});

  final int? maxSourceLength;

  bool _fitsSourceLimit(TextEditingValue next) =>
      maxSourceLength == null ||
      LengthLimitingTextInputFormatter(
            maxSourceLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
          ).formatEditUpdate(value, next).text ==
          next.text;

  late final TextInputFormatter typingFormatter = _MarkdownTypingFormatter(
    this,
  );
  Set<String>? _typingFormats;
  String? _typingSource;
  int? _typingCaret;

  Set<String> get activeFormats {
    if (_typingFormats != null &&
        (_typingSource != text || _typingCaret != selection.extentOffset)) {
      _typingFormats = null;
    }
    if (selection.isValid && !selection.isCollapsed) {
      return _formatsInSelection(text, selection);
    }
    return _typingFormats ??
        _inlineWrappersAt(
          text,
          selection.isValid ? selection.extentOffset : text.length,
        ).expand((wrapper) => wrapper.formats).toSet();
  }

  bool isFormatActive(String marker) => activeFormats.contains(marker);

  void format(
    String marker, {
    bool block = false,
    bool numbered = false,
    bool toggle = false,
    String? closing,
  }) {
    if (!block && (!selection.isValid || selection.isCollapsed)) {
      final formats = {...activeFormats};
      if (!formats.remove(marker)) formats.add(marker);
      _rememberTyping(value, formats);
      notifyListeners();
      return;
    }
    final pending = block && _typingFormats != null ? {...activeFormats} : null;
    _typingFormats = null;
    final next = formatMarkdown(
      value,
      marker,
      block: block,
      numbered: numbered,
      toggle: toggle,
      closing: closing,
    );
    if (_fitsSourceLimit(next)) value = next;
    if (pending != null) _rememberTyping(value, pending);
  }

  void insertDivider() {
    _typingFormats = null;
    final next = insertMarkdownDivider(value);
    if (_fitsSourceLimit(next)) value = next;
  }

  TextEditingValue _rememberTyping(TextEditingValue next, Set<String> formats) {
    _typingFormats = formats;
    _typingSource = next.text;
    _typingCaret = next.selection.extentOffset;
    return next;
  }

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
        math.min(MediaQuery.sizeOf(context).width, kResponsiveContentMaxWidth) -
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
                    fontSize: kHiddenMarkdownFontSize,
                    height: 1,
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
              fontSize: kHiddenMarkdownFontSize,
              height: 1,
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
      RegExp(r'\*\*\*(.+?)\*\*\*'),
      3,
      3,
      style.copyWith(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        fontVariations: const [FontVariation('wght', 700)],
      ),
    ),
    (
      RegExp(r'___(.+?)___'),
      3,
      3,
      style.copyWith(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        fontVariations: const [FontVariation('wght', 700)],
      ),
    ),
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
  final revealThis =
      revealRange != null &&
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

class _InlineWrapper {
  const _InlineWrapper(this.open, this.close, this.formats);
  final String open;
  final String close;
  final Set<String> formats;
}

const _inlineWrappers = {
  '**': _InlineWrapper('**', '**', {'**'}),
  '__': _InlineWrapper('__', '__', {'**'}),
  '*': _InlineWrapper('*', '*', {'*'}),
  '_': _InlineWrapper('_', '_', {'*'}),
  '***': _InlineWrapper('***', '***', {'**', '*'}),
  '___': _InlineWrapper('___', '___', {'**', '*'}),
  '<u>': _InlineWrapper('<u>', '</u>', {'<u>'}),
  '~~': _InlineWrapper('~~', '~~', {}),
  '`': _InlineWrapper('`', '`', {}),
};

Set<String> _formatsInSelection(String text, TextSelection selection) {
  Set<String>? common;
  var offset = 0;
  for (final line in text.split('\n')) {
    final prefix = RegExp(r'^\s{0,3}(#{1,6}\s|[-*+]\s|•\s|\d+\.\s)')
        .firstMatch(line);
    final content = line.substring(prefix?.end ?? 0);
    offset += prefix?.end ?? 0;
    for (final span in markdownInlineSpans(
      content,
      const TextStyle(),
    ).whereType<TextSpan>()) {
      final source = span.text ?? '';
      final end = offset + source.length;
      if (span.style?.fontSize != kHiddenMarkdownFontSize &&
          source.trim().isNotEmpty &&
          offset < selection.end &&
          end > selection.start) {
        final formats = {
          if (span.style?.fontWeight == FontWeight.bold) '**',
          if (span.style?.fontStyle == FontStyle.italic) '*',
          if (span.style?.decoration?.contains(TextDecoration.underline) ??
              false)
            '<u>',
        };
        common = common == null ? formats : common.intersection(formats);
      }
      offset = end;
    }
    offset++;
  }
  return common ?? {};
}

List<_InlineWrapper> _inlineWrappersAt(String text, int at) {
  at = at.clamp(0, text.length);
  final start = at == 0 ? 0 : text.lastIndexOf('\n', at - 1) + 1;
  final end = text.indexOf('\n', at);
  final line = text.substring(start, end < 0 ? text.length : end);
  final stack = <_InlineWrapper>[];
  var offset = start;
  for (final span in markdownInlineSpans(
    line,
    const TextStyle(),
  ).whereType<TextSpan>()) {
    final source = span.text ?? '';
    offset += source.length;
    if (offset > at) break;
    if (span.style?.fontSize == kHiddenMarkdownFontSize) {
      if (stack.isNotEmpty && stack.last.close == source) {
        stack.removeLast();
      } else if (_inlineWrappers[source] case final wrapper?) {
        stack.add(wrapper);
      }
    }
  }
  return stack;
}

String _closeInlinePrefix(String text, List<_InlineWrapper> wrappers) {
  for (final wrapper in wrappers.reversed) {
    text = text.endsWith(wrapper.open)
        ? text.substring(0, text.length - wrapper.open.length)
        : '$text${wrapper.close}';
  }
  return text;
}

String _openInlineSuffix(String text, List<_InlineWrapper> wrappers) {
  for (final wrapper in wrappers.reversed) {
    text = text.startsWith(wrapper.close)
        ? text.substring(wrapper.close.length)
        : '${wrapper.open}$text';
  }
  return text;
}

int _visibleContentEnd(String source) {
  final start = source.lastIndexOf('\n') + 1;
  var offset = start;
  var end = start;
  for (final span in markdownInlineSpans(
    source.substring(start),
    const TextStyle(),
  ).whereType<TextSpan>()) {
    offset += span.text?.length ?? 0;
    if (span.style?.fontSize != kHiddenMarkdownFontSize &&
        (span.text?.isNotEmpty ?? false)) {
      end = offset;
    }
  }
  return end;
}

class _MarkdownTypingFormatter extends TextInputFormatter {
  _MarkdownTypingFormatter(this.controller);
  final LiveMarkdownController controller;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final pendingIsCurrent =
        controller._typingFormats != null &&
        controller._typingSource == oldValue.text &&
        controller._typingCaret == oldValue.selection.extentOffset;
    final formats = pendingIsCurrent
        ? controller._typingFormats!
        : _inlineWrappersAt(
            oldValue.text,
            oldValue.selection.isValid
                ? oldValue.selection.extentOffset
                : oldValue.text.length,
          ).expand((wrapper) => wrapper.formats).toSet();
    if (!pendingIsCurrent) controller._typingFormats = null;
    TextEditingValue remember(TextEditingValue next) =>
        controller._rememberTyping(
          controller._fitsSourceLimit(next) ? next : oldValue,
          formats,
        );
    if (newValue.isComposingRangeValid && !newValue.composing.isCollapsed) {
      return remember(newValue);
    }
    var start = 0;
    var oldEnd = oldValue.text.length;
    var newEnd = newValue.text.length;
    if (oldValue.isComposingRangeValid && !oldValue.composing.isCollapsed) {
      start = oldValue.composing.start;
      oldEnd = oldValue.composing.end;
      newEnd = (oldEnd + newValue.text.length - oldValue.text.length).clamp(
        start,
        newValue.text.length,
      );
    } else {
      if (oldValue.text == newValue.text) return newValue;
      while (start < oldEnd &&
          start < newEnd &&
          oldValue.text[start] == newValue.text[start]) {
        start++;
      }
      while (oldEnd > start &&
          newEnd > start &&
          oldValue.text[oldEnd - 1] == newValue.text[newEnd - 1]) {
        oldEnd--;
        newEnd--;
      }
    }
    final inserted = newValue.text.substring(start, newEnd);
    final before = _inlineWrappersAt(oldValue.text, start);
    final after = _inlineWrappersAt(oldValue.text, oldEnd);
    if (inserted.isEmpty) {
      var left = oldValue.text.substring(0, start);
      var right = oldValue.text.substring(oldEnd);
      for (final wrapper in before.reversed) {
        if (!left.endsWith(wrapper.open) || !right.startsWith(wrapper.close)) {
          break;
        }
        left = left.substring(0, left.length - wrapper.open.length);
        right = right.substring(wrapper.close.length);
      }
      return remember(
        TextEditingValue(
          text: '$left$right',
          selection: TextSelection.collapsed(offset: left.length),
        ),
      );
    }
    final current = before.expand((wrapper) => wrapper.formats).toSet();
    if (setEquals(current, formats) &&
        before.map((wrapper) => wrapper.open).join() ==
            after.map((wrapper) => wrapper.open).join() &&
        !inserted.contains('\n') &&
        inserted.trimRight() == inserted) {
      return remember(newValue);
    }
    final prefix = _closeInlinePrefix(
      oldValue.text.substring(0, start),
      before,
    );
    final suffix = _openInlineSuffix(oldValue.text.substring(oldEnd), after);
    var formatted = inserted;
    for (final marker in ['**', '*', '<u>']) {
      if (!formats.contains(marker)) continue;
      formatted = formatMarkdown(
        TextEditingValue(
          text: formatted,
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: formatted.length,
          ),
        ),
        marker,
        closing: marker == '<u>' ? '</u>' : null,
      ).text;
    }
    return remember(
      TextEditingValue(
        text: '$prefix$formatted$suffix',
        selection: TextSelection.collapsed(
          offset: prefix.length + _visibleContentEnd(formatted),
        ),
      ),
    );
  }
}
