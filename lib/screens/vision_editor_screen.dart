import '../utils/area_section_icons.dart';

import 'package:flutter/material.dart';

import '../data/area_vision_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../widgets/area_section_header.dart';
import '../widgets/live_markdown_controller.dart';
import '../widgets/logo_watermark.dart';
import '../widgets/responsive_content.dart';
import '../widgets/shareable_area_content_card.dart';
import '../widgets/staggered_entrance.dart';
import 'share_preview_screen.dart';

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
      final discard = await showAppConfirmation(
        context: context,
        title: strings.discardChangesConfirmTitle,
        body: strings.discardChangesConfirmBody,
        cancelLabel: strings.cancel,
        confirmLabel: strings.discardChangesAction,
        tone: AppConfirmationTone.destructive,
      );
      _asking = false;
      if (!discard || !mounted) return;
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

  Future<void> _share() => showSharePreview(
    context: context,
    content: ShareableVisionCard(
      area: widget.area,
      vision: _controller.text.trim().isEmpty
          ? widget.area.visionPlaceholder(context.strings)
          : _controller.text,
    ),
    fileName: 'vision_${widget.area.name}.png',
  );

  void _format(
    String marker, {
    bool block = false,
    bool numbered = false,
    bool toggle = false,
    String? closing,
  }) {
    _controller.format(
      marker,
      block: block,
      numbered: numbered,
      toggle: toggle,
      closing: closing,
    );
    _focus.requestFocus();
  }

  void _insertDivider() {
    _controller.insertDivider();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final strings = context.strings;
    final colors = context.colors;
    Widget tool(
      IconData icon,
      String label,
      VoidCallback action, {
      String? marker,
    }) => ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, child) => IconButton(
        tooltip: label,
        isSelected: marker == null ? null : _controller.isFormatActive(marker),
        style: IconButton.styleFrom(
          foregroundColor: colors.text,
          disabledForegroundColor: colors.muted,
        ),
        icon: Icon(icon),
        selectedIcon: Icon(icon, color: colors.gold),
        onPressed: _saving ? null : action,
      ),
    );
    return PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: colors.night,
        // Preserve the gesture-bar inset while the editor resizes above the keyboard.
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StaggeredEntrance(
                  index: 0,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      keyboardVisible ? 8 : 20,
                      20,
                      keyboardVisible ? 8 : 16,
                    ),
                    child: AreaSectionHeader(
                      compact: keyboardVisible,
                      title: widget.area.displayName(strings),
                      icon: kAreaVisionIcon,
                      description: strings.visionPageDescription,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: TextFieldTapRegion(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StaggeredEntrance(
                              index: 1,
                              axis: Axis.horizontal,
                              child: PopupMenuButton<int>(
                                requestFocus: false,
                                tooltip: strings.visionHeading,
                                enabled: !_saving,
                                color: colors.nightPanel,
                                surfaceTintColor: Colors.transparent,
                                onSelected: (level) => _format(
                                  '${'#' * level} ',
                                  block: true,
                                  toggle: true,
                                ),
                                itemBuilder: (context) => [
                                  for (var level = 1; level <= 3; level++)
                                    PopupMenuItem(
                                      value: level,
                                      padding: EdgeInsets.zero,
                                      child: TextFieldTapRegion(
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: Center(
                                            child: Text(
                                              '${strings.visionHeading} $level',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: colors.text,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: Text(
                                      'H',
                                      style: TextStyle(
                                        color: colors.text,
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
                              child: SizedBox(
                                height: 24,
                                child: VerticalDivider(
                                  width: 24,
                                  thickness: 0.75,
                                  color: colors.nightBorder,
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
                                marker: '**',
                              ),
                            ),
                            StaggeredEntrance(
                              index: 3,
                              axis: Axis.horizontal,
                              child: tool(
                                Icons.format_italic,
                                strings.visionItalic,
                                () => _format('*', toggle: true),
                                marker: '*',
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
                                marker: '<u>',
                              ),
                            ),
                            StaggeredEntrance(
                              index: 4,
                              axis: Axis.horizontal,
                              child: SizedBox(
                                height: 24,
                                child: VerticalDivider(
                                  width: 24,
                                  thickness: 0.75,
                                  color: colors.nightBorder,
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
                              child: SizedBox(
                                height: 24,
                                child: VerticalDivider(
                                  width: 24,
                                  thickness: 0.75,
                                  color: colors.nightBorder,
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
                              child: SizedBox(
                                height: 24,
                                child: VerticalDivider(
                                  width: 24,
                                  thickness: 0.75,
                                  color: colors.nightBorder,
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
                                        foregroundColor: colors.text,
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
                                        foregroundColor: colors.text,
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
                ),
                StaggeredEntrance(
                  index: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      thickness: 0.75,
                      color: colors.nightBorder,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: LogoWatermark(
                          scale: logoWatermarkScale(StarKind.unlit),
                          color: logoWatermarkColor(colors, StarKind.unlit),
                        ),
                      ),
                      Padding(
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
                            inputFormatters: [_controller.typingFormatter],
                            strutStyle: const StrutStyle(
                              fontFamily: kFontStarTitle,
                              fontSize: 21,
                              height: 1.6,
                            ),
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
                              contentPadding: EdgeInsets.symmetric(
                                vertical: keyboardVisible ? 4 : 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                StaggeredEntrance(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : _share,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: keyboardVisible ? 8 : 22,
                              vertical: 14,
                            ),
                          ),
                          child: AppButtonLabel(
                            strings.starQuickLookShareAction,
                          ),
                        ),
                        ListenableBuilder(
                          listenable: _controller,
                          builder: (context, _) => ElevatedButton(
                            style: keyboardVisible
                                ? ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  )
                                : null,
                            onPressed: _saving || _controller.text == _initial
                                ? null
                                : _save,
                            child: AppButtonLabel(strings.saveChanges),
                          ),
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
    );
  }
}
