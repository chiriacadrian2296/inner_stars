import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Source-preserving toolbar operations shared by Vision and Reflections.
TextEditingValue formatMarkdown(
  TextEditingValue value,
  String marker, {
  bool block = false,
  bool numbered = false,
  bool toggle = false,
  String? closing,
}) {
  final selection = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  // Inline formatting needs content to act on. Inserting an empty pair of
  // Markdown delimiters would expose implementation syntax in the editor.
  if (!block && selection.isCollapsed) return value;
  if (value.isComposingRangeValid && !value.composing.isCollapsed) return value;
  var start = selection.start;
  var end = selection.end;
  final closingMarker = closing ?? marker;
  String replacement;
  int selectionStart;
  int selectionEnd;
  if (block) {
    start = start == 0 ? 0 : value.text.lastIndexOf('\n', start - 1) + 1;
    if (end > start && value.text[end - 1] == '\n') end--;
    final lineEnd = value.text.indexOf('\n', end);
    end = lineEnd < 0 ? value.text.length : lineEnd;
    final lines = value.text.substring(start, end).split('\n');
    final blockPrefix = RegExp(r'^\s{0,3}(#{1,6}\s|[-*+]\s|•\s|\d+\.\s)');
    bool isDivider(String line) => RegExp(r'^\s*---+\s*$').hasMatch(line);
    final applicableLines = lines.where((line) => !isDivider(line));
    final alreadyApplied =
        toggle &&
        applicableLines.isNotEmpty &&
        applicableLines.every(
          numbered
              ? (line) => RegExp(r'^\s{0,3}\d+\.\s').hasMatch(line)
              : (line) => line.startsWith(marker),
        );
    var number = 0;
    replacement = lines
        .map((line) {
          if (isDivider(line)) return line;
          final content = line.replaceFirst(blockPrefix, '');
          if (alreadyApplied) return content;
          number++;
          return '${numbered ? '$number. ' : marker}$content';
        })
        .join('\n');
    selectionStart = start + replacement.length;
    selectionEnd = selectionStart;
  } else {
    if (toggle && !selection.isCollapsed) {
      final selectedStart = start;
      final selectedEnd = end;
      for (final match in _inlinePattern(marker).allMatches(value.text)) {
        if (match.start < selectedEnd && match.end > selectedStart) {
          start = math.min(start, match.start);
          end = math.max(end, match.end);
        }
      }
    }
    final selected = value.text.substring(start, end);
    final lines = selected.split('\n');
    final blockPrefix = RegExp(r'^\s{0,3}(#{1,6}\s|[-*+]\s|•\s|\d+\.\s)');
    bool isDivider(String line) => RegExp(r'^\s*---+\s*$').hasMatch(line);
    String contentOf(String line) => line.replaceFirst(blockPrefix, '');
    bool wrapped(String line) {
      final content = contentOf(line).trim();
      if (marker == '*' || marker == '**') {
        final opening =
            RegExp(r'^\*+').firstMatch(content)?.group(0)?.length ?? 0;
        final closing =
            RegExp(r'\*+$').firstMatch(content)?.group(0)?.length ?? 0;
        final counts = marker == '*' ? const [1, 3] : const [2, 3];
        return counts.contains(opening) &&
            counts.contains(closing) &&
            content.length > opening + closing;
      }
      return content.startsWith(marker) &&
          content.endsWith(closingMarker) &&
          content.length >= marker.length + closingMarker.length;
    }

    final formattableLines = lines.where(
      (line) => line.trim().isNotEmpty && !isDivider(line),
    );
    final alreadyApplied =
        toggle &&
        formattableLines.isNotEmpty &&
        formattableLines.every(wrapped);
    replacement = lines
        .map((line) {
          if (line.isEmpty || isDivider(line)) return line;
          final prefixMatch = blockPrefix.firstMatch(line);
          final prefix = prefixMatch?[0] ?? '';
          final lineContent = line.substring(prefix.length);
          final parts = RegExp(r'^(\s*)(.*?)(\s*)$').firstMatch(lineContent)!;
          final leading = parts[1]!;
          final inner = parts[2]!;
          final trailing = parts[3]!;
          if (inner.isEmpty) return line;
          if (alreadyApplied) {
            return '$prefix$leading${inner.substring(marker.length, inner.length - closingMarker.length)}$trailing';
          }
          final content = toggle
              ? _withoutInlineMarkers(inner, marker, closingMarker)
              : inner;
          return '$prefix$leading$marker$content$closingMarker$trailing';
        })
        .join('\n');
    selectionStart = start;
    selectionEnd = start + replacement.length;
  }
  return TextEditingValue(
    text: value.text.replaceRange(start, end, replacement),
    selection: TextSelection(
      baseOffset: selectionStart,
      extentOffset: selectionEnd,
    ),
  );
}

String _withoutInlineMarkers(String text, String marker, String closingMarker) {
  if (marker == '*') {
    return text.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
  }
  return text.replaceAll(marker, '').replaceAll(closingMarker, '');
}

RegExp _inlinePattern(String marker) => switch (marker) {
  '**' => RegExp(
    r'(?<!\*)\*{3}(?!\*)(.+?)(?<!\*)\*{3}(?!\*)|(?<!\*)\*{2}(?!\*)(.+?)(?<!\*)\*{2}(?!\*)',
  ),
  '*' => RegExp(
    r'(?<!\*)\*{3}(?!\*)(.+?)(?<!\*)\*{3}(?!\*)|(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)',
  ),
  '<u>' => RegExp(r'<u>(.+?)</u>'),
  _ => RegExp('${RegExp.escape(marker)}(.+?)${RegExp.escape(marker)}'),
};

TextEditingValue insertMarkdownDivider(TextEditingValue value) {
  if (value.isComposingRangeValid && !value.composing.isCollapsed) return value;
  final text = value.text;
  final selection = value.selection;
  final cursor = selection.isValid ? selection.end : text.length;
  final lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
  final lineEnd = text.indexOf('\n', cursor);
  final at = lineEnd < 0 ? text.length : lineEnd;
  final line = text.substring(lineStart, at);
  final blockPrefix = RegExp(r'^\s{0,3}(#{1,6}\s|[-*+]\s|•\s|\d+\.\s)');
  final content = line.replaceFirst(blockPrefix, '').trim();
  if (RegExp(r'^\s*---+\s*$').hasMatch(line)) {
    return TextEditingValue(
      text: text.replaceRange(lineStart, at, ''),
      selection: TextSelection.collapsed(offset: lineStart),
    );
  }
  if (content.isEmpty) {
    return TextEditingValue(
      text: text.replaceRange(lineStart, at, '---'),
      selection: TextSelection.collapsed(offset: lineStart + 3),
    );
  }
  final replaceEnd = at < text.length && text[at] == '\n' ? at + 1 : at;
  const rule = '\n\n---\n\n';
  return TextEditingValue(
    text: text.replaceRange(at, replaceEnd, rule),
    selection: TextSelection.collapsed(offset: at + rule.length),
  );
}
