import '../utils/area_section_icons.dart';

import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';

import '../data/area_vision_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../widgets/area_section_header.dart';
import '../widgets/app_rich_text_editor.dart';
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
  late final _controller = AppRichTextController(
    legacy: _initial,
    richText: widget.repository.getRichText(widget.area),
  );
  final _editorKey = GlobalKey<EditorState>();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_syncFocus);
  }

  void _syncFocus() {
    if (mounted) setState(() {});
  }

  bool _saving = false;
  bool _canLeave = false;
  bool _asking = false;

  @override
  void dispose() {
    _focus.removeListener(_syncFocus);
    _controller.dispose();
    _focus.dispose();

    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving || _asking) return;
    if (_controller.hasChanges) {
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
      final snapshot = _controller.snapshot;
      await widget.repository.setVision(
        widget.area,
        _controller.isEmpty ? '' : snapshot.legacyText,
        richText: _controller.isEmpty ? null : snapshot,
      );
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
      richText: _controller.isEmpty ? null : _controller.snapshot,
      vision: _controller.isEmpty
          ? widget.area.visionPlaceholder(context.strings)
          : _controller.snapshot.legacyText,
    ),
    fileName: 'vision_${widget.area.name}.png',
  );

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final strings = context.strings;
    final colors = context.colors;
    return PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: colors.night,
        // Keep page chrome behind the keyboard; only the editor viewport shrinks.
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: ResponsiveContent(
            child: AppRichTextPageLayout(
              toolbar: _toolbar(),
              backdrop: LogoWatermark(
                scale: logoWatermarkScale(StarKind.unlit),
                color: logoWatermarkColor(colors, StarKind.unlit),
              ),
              header: StaggeredEntrance(
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
              editor: AppRichTextEditor(
                controller: _controller,
                focusNode: _focus,
                editorKey: _editorKey,
                hint: strings.visionEditorHint,
                readOnly: _saving,
              ),
              actions: StaggeredEntrance(
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
                            horizontal: 22,
                            vertical: 14,
                          ),
                        ),
                        child: AppButtonLabel(strings.starQuickLookShareAction),
                      ),
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) => ElevatedButton(
                          onPressed: _saving || !_controller.hasChanges
                              ? null
                              : _save,
                          child: AppButtonLabel(strings.saveChanges),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar() => AppRichTextToolbar(
    controller: _controller,
    focusNode: _focus,
    editorKey: _editorKey,
    enabled: !_saving,
  );
}
