import 'package:flutter/material.dart';

import '../data/area_vision_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../widgets/area_tag.dart';
import '../widgets/responsive_content.dart';
import '../widgets/vision_markdown.dart';

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
  late final _controller = TextEditingController(text: _initial);
  final _focus = FocusNode();
  final _undo = UndoHistoryController();
  bool _preview = false;
  bool _saving = false;
  bool _canLeave = false;
  bool _asking = false;

  @override
  void dispose() {
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
      final discard = await showDialog<bool>(
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

  void _format(String marker, {bool block = false, bool numbered = false}) {
    final value = _controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    var start = selection.start;
    var end = selection.end;
    String replacement;
    int selectionStart;
    int selectionEnd;
    if (block) {
      start = start == 0 ? 0 : value.text.lastIndexOf('\n', start - 1) + 1;
      if (end > start && value.text[end - 1] == '\n') end--;
      final lineEnd = value.text.indexOf('\n', end);
      end = lineEnd < 0 ? value.text.length : lineEnd;
      final lines = value.text.substring(start, end).split('\n');
      replacement = lines.indexed
          .map(
            (entry) =>
                '${numbered ? '${entry.$1 + 1}. ' : marker}${entry.$2.replaceFirst(RegExp(r'^\s{0,3}(#{1,6}\s|[-*+]\s|\d+\.\s)'), '')}',
          )
          .join('\n');
      selectionStart = start + replacement.length;
      selectionEnd = selectionStart;
    } else {
      replacement = '$marker${value.text.substring(start, end)}$marker';
      selectionStart = start + marker.length;
      selectionEnd = end + marker.length;
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    Widget tool(IconData icon, String label, VoidCallback action) => IconButton(
      tooltip: label,
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _leave,
          ),
          title: Text(strings.editVisionAction),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: AreaTag(area: widget.area),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(strings.visionWrite),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(strings.visionPreview),
                        icon: const Icon(Icons.visibility_outlined),
                      ),
                    ],
                    selected: {_preview},
                    onSelectionChanged: (value) {
                      _focus.unfocus();
                      setState(() => _preview = value.first);
                    },
                  ),
                ),
                if (!_preview)
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          tool(
                            Icons.title,
                            strings.visionHeading,
                            () => _format('# ', block: true),
                          ),
                          tool(
                            Icons.subtitles_outlined,
                            strings.visionSection,
                            () => _format('## ', block: true),
                          ),
                          tool(
                            Icons.format_bold,
                            strings.visionBold,
                            () => _format('**'),
                          ),
                          tool(
                            Icons.format_italic,
                            strings.visionItalic,
                            () => _format('*'),
                          ),
                          tool(
                            Icons.format_list_bulleted,
                            strings.visionBulletList,
                            () => _format('- ', block: true),
                          ),
                          tool(
                            Icons.format_list_numbered,
                            strings.visionNumberedList,
                            () => _format('1. ', block: true, numbered: true),
                          ),
                          const SizedBox(
                            height: 24,
                            child: VerticalDivider(width: 24, thickness: 1),
                          ),
                          ValueListenableBuilder<UndoHistoryValue>(
                            valueListenable: _undo,
                            builder: (context, value, _) => Row(
                              children: [
                                IconButton(
                                  tooltip: strings.visionUndo,
                                  icon: const Icon(Icons.undo),
                                  onPressed: value.canUndo && !_saving
                                      ? _undo.undo
                                      : null,
                                ),
                                IconButton(
                                  tooltip: strings.visionRedo,
                                  icon: const Icon(Icons.redo),
                                  onPressed: value.canRedo && !_saving
                                      ? _undo.redo
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: _preview
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: VisionMarkdown(
                            data: _controller.text.isEmpty
                                ? strings.visionEmptyLabel
                                : _controller.text,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
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
                              fontSize: 17,
                              height: 1.6,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: strings.visionEditorHint,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 20,
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
