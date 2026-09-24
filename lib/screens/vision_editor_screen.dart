import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/area_vision_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../utils/app_modals.dart';
import '../widgets/area_section_header.dart';
import '../widgets/live_markdown_controller.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';

class VisionEditorScreen extends StatefulWidget {
  const VisionEditorScreen({
    super.key,
    required this.area,
    required this.repository,
  });
  final LifeArea area;
  final AreaVisionRepository repository;

  @override
  State<VisionEditorScreen> createState() => _VisionEditorScreenState();
}

class _VisionEditorScreenState extends State<VisionEditorScreen> {
  late final String _initial = widget.repository.getVision(widget.area);
  late final _controller = LiveMarkdownController(text: _initial);
  final _focus = FocusNode();
  final _undo = UndoHistoryController();
  @override
  void initState() {
    super.initState();
    _focus.addListener(_syncFocus);
  }

  void _syncFocus() => _controller.focused = _focus.hasFocus;
  bool _saving = false;
  bool _canLeave = false;
  bool _asking = false;

  @override
  void dispose() {
    _focus.removeListener(_syncFocus);
    _controller.dispose();
    _focus.dispose();
    _undo.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving || _asking) return;
    if (_controller.text != _initial) {
      _asking = true;
      final strings = context.strings;
      final discard = await showAppDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.discardChangesConfirmTitle),
          content: Text(strings.discardChangesConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.discardChangesAction),
            ),
          ],
        ),
      );
      _asking = false;
      if (discard != true || !mounted) return;
    }
    _close();
  }

  void _close() {
    setState(() => _canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.setVision(widget.area, _controller.text);
      if (mounted) _close();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.visionSaveError)));
    }
  }

  void _format(
    String marker, {
    bool block = false,
    bool numbered = false,
    bool toggle = false,
    String? closing,
  }) {
    final value = _controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    // Inline formatting needs content to act on. Inserting an empty pair of
    // Markdown delimiters would expose implementation syntax in the editor.
    if (!block && selection.isCollapsed) return;
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
      final alreadyApplied = toggle &&
          applicableLines.isNotEmpty &&
          applicableLines.every(
            numbered
                ? (line) => RegExp(r'^\s{0,3}\d+\.\s').hasMatch(line)
                : (line) => line.startsWith(marker),
          );
      replacement = lines.indexed
          .map((entry) {
            if (isDivider(entry.$2)) return entry.$2;
            final content = entry.$2.replaceFirst(blockPrefix, '');
            if (alreadyApplied) return content;
            return '${numbered ? '${entry.$1 + 1}. ' : marker}$content';
          })
          .join('\n');
      selectionStart = start + replacement.length;
      selectionEnd = selectionStart;
    } else {
      if (toggle && !selection.isCollapsed) {
        final selectedStart = start;
        final selectedEnd = end;
        for (final match in _inlinePattern(
          marker,
        ).allMatches(value.text)) {
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
        final content = contentOf(line);
        return content.startsWith(marker) &&
            content.endsWith(closingMarker) &&
            content.length >= marker.length + closingMarker.length;
      }

      final formattableLines = lines.where(
        (line) => line.isNotEmpty && !isDivider(line),
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
            if (alreadyApplied) {
              return '$prefix${lineContent.substring(
                marker.length,
                lineContent.length - closingMarker.length,
              )}';
            }
            final content = toggle
                ? _withoutInlineMarkers(lineContent, marker, closingMarker)
                : lineContent;
            return '$prefix$marker$content$closingMarker';
          })
          .join('\n');
      selectionStart = start;
      selectionEnd = start + replacement.length;
    }
    _controller.value = TextEditingValue(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: selectionEnd,
      ),
    );
    _focus.requestFocus();
  }

  String _withoutInlineMarkers(
    String text,
    String marker,
    String closingMarker,
  ) {
    if (marker == '*') {
      return text.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
    }
    return text.replaceAll(marker, '').replaceAll(closingMarker, '');
  }

  RegExp _inlinePattern(String marker) => switch (marker) {
    '**' => RegExp(r'\*\*(.+?)\*\*'),
    '*' => RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'),
    '<u>' => RegExp(r'<u>(.+?)</u>'),
    _ => RegExp('${RegExp.escape(marker)}(.+?)${RegExp.escape(marker)}'),
  };

  void _insertDivider() {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursor = selection.isValid ? selection.end : text.length;
    final lineStart = cursor == 0
        ? 0
        : text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final at = lineEnd < 0 ? text.length : lineEnd;
    final line = text.substring(lineStart, at);
    final blockPrefix = RegExp(r'^\s{0,3}(#{1,6}\s|[-*+]\s|•\s|\d+\.\s)');
    final content = line.replaceFirst(blockPrefix, '').trim();
    if (RegExp(r'^\s*---+\s*$').hasMatch(line)) {
      _controller.value = TextEditingValue(
        text: text.replaceRange(lineStart, at, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
      _focus.requestFocus();
      return;
    }
    if (content.isEmpty) {
      _controller.value = TextEditingValue(
        text: text.replaceRange(lineStart, at, '---'),
        selection: TextSelection.collapsed(offset: lineStart + 3),
      );
      _focus.requestFocus();
      return;
    }
    final replaceEnd = at < text.length && text[at] == '\n' ? at + 1 : at;
    const rule = '\n\n---\n\n';
    _controller.value = TextEditingValue(
      text: text.replaceRange(at, replaceEnd, rule),
      selection: TextSelection.collapsed(offset: at + rule.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    Widget tool(IconData icon, String label, VoidCallback action) => IconButton(
      tooltip: label,
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: colors.muted,
      ),
      icon: Icon(icon),
      onPressed: _saving ? null : action,
    );
    return PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: colors.night,
        appBar: AppBar(
          elevation: 20,
          scrolledUnderElevation: 20,
          shadowColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _leave,
          ),
          title: Text(widget.area.displayName(strings)),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(strings.saveChanges),
            ),
          ],
        ),
        body: SafeArea(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StaggeredEntrance(
                  index: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: AreaSectionHeader(
                      title: strings.visionPageTitle,
                      description: strings.visionPageDescription,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        StaggeredEntrance(
                          index: 1,
                          axis: Axis.horizontal,
                          child: PopupMenuButton<int>(
                            tooltip: strings.visionHeading,
                            enabled: !_saving,
                            color: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            onSelected: (level) =>
                                _format(
                                  '${'#' * level} ',
                                  block: true,
                                  toggle: true,
                                ),
                            itemBuilder: (context) => [
                              for (var level = 1; level <= 3; level++)
                                PopupMenuItem(
                                  value: level,
                                  child: Center(
                                    child: Text(
                                      '${strings.visionHeading} $level',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Text(
                                  'H',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 1,
                          axis: Axis.horizontal,
                          child: const SizedBox(
                            height: 24,
                            child: VerticalDivider(
                              width: 24,
                              thickness: 0.75,
                              color: Color(0x47FFFFFF),
                            ),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 2,
                          axis: Axis.horizontal,
                          child: tool(
                            Icons.format_bold,
                            strings.visionBold,
                            () => _format('**', toggle: true),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 3,
                          axis: Axis.horizontal,
                          child: tool(
                            Icons.format_italic,
                            strings.visionItalic,
                            () => _format('*', toggle: true),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 4,
                          axis: Axis.horizontal,
                          child: tool(
                            Icons.format_underlined,
                            strings.visionUnderline,
                            () => _format(
                              '<u>',
                              closing: '</u>',
                              toggle: true,
                            ),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 4,
                          axis: Axis.horizontal,
                          child: const SizedBox(
                            height: 24,
                            child: VerticalDivider(
                              width: 24,
                              thickness: 0.75,
                              color: Color(0x47FFFFFF),
                            ),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 5,
                          axis: Axis.horizontal,
                          child: tool(
                            Icons.format_list_bulleted,
                            strings.visionBulletList,
                            () => _format('• ', block: true, toggle: true),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 6,
                          axis: Axis.horizontal,
                          child: tool(
                            Icons.format_list_numbered,
                            strings.visionNumberedList,
                            () => _format(
                              '1. ',
                              block: true,
                              numbered: true,
                              toggle: true,
                            ),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 6,
                          axis: Axis.horizontal,
                          child: const SizedBox(
                            height: 24,
                            child: VerticalDivider(
                              width: 24,
                              thickness: 0.75,
                              color: Color(0x47FFFFFF),
                            ),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 7,
                          axis: Axis.horizontal,
                          child: tool(
                            Icons.horizontal_rule,
                            strings.visionDivider,
                            _insertDivider,
                          ),
                        ),
                        StaggeredEntrance(
                          index: 7,
                          axis: Axis.horizontal,
                          child: const SizedBox(
                            height: 24,
                            child: VerticalDivider(
                              width: 24,
                              thickness: 0.75,
                              color: Color(0x47FFFFFF),
                            ),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 8,
                          axis: Axis.horizontal,
                          child: ValueListenableBuilder<UndoHistoryValue>(
                            valueListenable: _undo,
                            builder: (context, value, _) => Row(
                              children: [
                                IconButton(
                                  tooltip: strings.visionUndo,
                                  style: IconButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: colors.muted,
                                  ),
                                  icon: const Icon(Icons.undo),
                                  onPressed: value.canUndo && !_saving
                                      ? _undo.undo
                                      : null,
                                ),
                                IconButton(
                                  tooltip: strings.visionRedo,
                                  style: IconButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: colors.muted,
                                  ),
                                  icon: const Icon(Icons.redo),
                                  onPressed: value.canRedo && !_saving
                                      ? _undo.redo
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
                StaggeredEntrance(
                  index: 1,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      thickness: 0.75,
                      color: Color(0x47FFFFFF),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: StaggeredEntrance(
                      index: 2,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        undoController: _undo,
                        readOnly: _saving,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontFamily: kFontStarTitle,
                          fontStyle: FontStyle.normal,
                          color: colors.text,
                          fontSize: 21,
                          height: 1.6,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          hintText: strings.visionEditorHint,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
