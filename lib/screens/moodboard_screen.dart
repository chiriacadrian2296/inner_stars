import '../utils/area_section_icons.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/moodboard_repository.dart';
import '../data/moodboard_storage.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../widgets/app_field.dart';
import '../widgets/area_section_header.dart';
import '../widgets/moodboard_grid.dart';
import '../widgets/logo_watermark.dart';
import '../widgets/responsive_content.dart';
import '../widgets/shareable_area_content_card.dart';
import '../widgets/staggered_entrance.dart';
import 'share_preview_screen.dart';

class MoodboardScreen extends StatefulWidget {
  const MoodboardScreen({
    super.key,
    required this.area,
    required this.repository,
  });
  final LifeArea area;
  final MoodboardRepository repository;
  @override
  State<MoodboardScreen> createState() => _MoodboardScreenState();
}

class _MoodboardScreenState extends State<MoodboardScreen> {
  bool _busy = false;
  List<MoodboardItem> get _items => widget.repository.getItems(widget.area);

  Future<void> _share() => showSharePreview(
    context: context,
    content: ShareableMoodboardCard(area: widget.area, items: _items),
    shareText:
        '${context.strings.moodboardTitle} - ${widget.area.displayName(context.strings)}',
    fileName: 'moodboard_${widget.area.name}.png',
  );
  void _error() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.moodboardSaveError)),
      );
    }
  }

  Future<void> _addMedia(MoodboardKind kind) async {
    setState(() => _busy = true);
    final paths = <String>[];
    var saved = false;
    try {
      final picker = ImagePicker();
      // Photos come several at a time; a video is still one.
      final List<XFile> files;
      if (kind == MoodboardKind.photo) {
        files = await picker.pickMultiImage(maxWidth: 2400, imageQuality: 90);
      } else {
        final video = await picker.pickVideo(source: ImageSource.gallery);
        files = video == null ? const [] : [video];
      }
      if (files.isEmpty) return;
      for (final file in files) {
        paths.add(await MoodboardStorage.save(file));
      }
      final stamp = DateTime.now().microsecondsSinceEpoch;
      await widget.repository.save(widget.area, [
        ..._items,
        for (var i = 0; i < paths.length; i++)
          MoodboardItem(id: '${stamp + i}', kind: kind, content: paths[i]),
      ]);
      saved = true;
    } catch (_) {
      _error();
    } finally {
      if (!saved) {
        for (final path in paths) {
          try {
            await MoodboardStorage.delete(path);
          } catch (_) {}
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Asks which kind to add, in the same sheet as the menu's Light Your Sky.
  Future<void> _add() async {
    final strings = context.strings;
    final kind = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) {
        Widget choice(IconData icon, String label, String value, int index) =>
            StaggeredEntrance(
              index: index,
              child: AppSheetAction(
                icon: icon,
                label: label,
                onPressed: () => Navigator.of(sheetContext).pop(value),
              ),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSheetTitle(strings.moodboardAddLabel),
                const SizedBox(height: 20),
                choice(
                  Icons.add_photo_alternate_outlined,
                  strings.photoLabel,
                  'photo',
                  0,
                ),
                const SizedBox(height: 10),
                choice(
                  Icons.video_library_outlined,
                  strings.moodboardVideo,
                  'video',
                  1,
                ),
                const SizedBox(height: 10),
                choice(Icons.format_quote, strings.moodboardQuote, 'quote', 2),
                const SizedBox(height: 24),
                Align(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: AppButtonLabel(strings.cancel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    switch (kind) {
      case 'photo':
        await _addMedia(MoodboardKind.photo);
      case 'video':
        await _addMedia(MoodboardKind.video);
      case 'quote':
        await _quote();
    }
  }

  Future<void> _quote([MoodboardItem? existing]) async {
    // Fixed sheet: the keyboard covers its lower part instead of moving it.
    final result = await showFixedAppSheet<_QuoteDraft>(
      context: context,
      builder: (_) => _QuoteEditorSheet(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final item = MoodboardItem(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        kind: MoodboardKind.quote,
        content: result.text,
        author: result.author,
        quoteStyle: result.style,
      );
      await widget.repository.save(
        widget.area,
        existing == null
            ? [..._items, item]
            : [for (final old in _items) old.id == item.id ? item : old],
      );
    } catch (_) {
      _error();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _open(MoodboardItem item) async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (routeContext) => InheritedTheme.captureAll(
          context,
          Scaffold(
            backgroundColor: context.colors.night,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: item.kind == MoodboardKind.quote
                        ? SizedBox.expand(
                            child: MoodboardMedia(item: item, expanded: true),
                          )
                        : MoodboardMedia(item: item, expanded: true),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item.kind == MoodboardKind.quote)
                        IconButton(
                          tooltip: context.strings.moodboardEdit,
                          onPressed: () => Navigator.pop(context, 'edit'),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      IconButton(
                        tooltip: context.strings.moodboardRemove,
                        onPressed: () async {
                          final confirmed = await showAppConfirmation(
                            context: context,
                            title: context.strings.moodboardRemoveConfirm,
                            body: context.strings.moodboardRemoveDescription,
                            cancelLabel: context.strings.cancel,
                            confirmLabel: context.strings.moodboardRemove,
                            tone: AppConfirmationTone.destructive,
                          );
                          if (confirmed && mounted) {
                            Navigator.pop(context, 'delete');
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _quote(item);
    }
    if (action == 'delete') {
      setState(() => _busy = true);
      try {
        await widget.repository.save(
          widget.area,
          _items.where((e) => e.id != item.id).toList(),
        );
        if (item.kind != MoodboardKind.quote) {
          await MoodboardStorage.delete(item.content);
        }
      } catch (_) {
        _error();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      backgroundColor: context.colors.night,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              // Keep the mark inside the canvas that begins below the
              // heading and the add-media controls.
              top: 150,
              bottom: 0,
              child: LogoWatermark(
                scale: logoWatermarkScale(StarKind.unlit),
                color: logoWatermarkColor(context.colors, StarKind.unlit),
              ),
            ),
            if (_items.isEmpty)
              Positioned(
                left: 24,
                right: 24,
                top: 150,
                bottom: 0,
                child: Center(
                  child: StaggeredEntrance(
                    index: 4,
                    child: Text(
                      strings.moodboardEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.muted),
                    ),
                  ),
                ),
              ),
            // The scroll view spans the full window width (wheel works
            // anywhere, scrollbar at the page edge); only its content is
            // capped/centered.
            Column(
              children: [
                if (_busy)
                  ResponsiveContent(
                    child: LinearProgressIndicator(color: context.colors.gold),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: ResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StaggeredEntrance(
                            index: 0,
                            child: AreaSectionHeader(
                              title: widget.area.displayName(strings),
                              icon: kAreaMoodboardIcon,
                              description: strings.moodboardPageDescription,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // The grid staggers its own tiles (see MoodboardGrid).
                          MoodboardGrid(
                            items: _items,
                            onTap: _busy ? null : _open,
                            showEmptyMessage: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                StaggeredEntrance(
                  index: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : _share,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                          ),
                          child: AppButtonLabel(
                            strings.starQuickLookShareAction,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _busy ? null : _add,
                          child: AppButtonLabel(strings.moodboardAddLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteDraft {
  const _QuoteDraft({
    required this.text,
    required this.author,
    required this.style,
  });

  final String text;
  final String author;
  final MoodboardQuoteStyle style;
}

class _QuoteEditorSheet extends StatefulWidget {
  const _QuoteEditorSheet({this.existing});

  final MoodboardItem? existing;

  @override
  State<_QuoteEditorSheet> createState() => _QuoteEditorSheetState();
}

/// A quote is a caption on a card, not an essay.
const int _kQuoteMaxLength = 250;
const int _kQuoteAuthorMaxLength = 50;

class _QuoteEditorSheetState extends State<_QuoteEditorSheet>
    with WidgetsBindingObserver {
  /// The real keyboard height. The sheet itself ignores it (so it never
  /// moves); it only pads the scroll content so every field can be scrolled
  /// above the keyboard.
  double _keyboard = 0;
  final _frameKey = GlobalKey();
  double? _fitted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Measured once, before the keyboard opens, so the sheet is exactly as
    // tall as its content (no gap) and then stays that height.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _frameKey.currentContext?.findRenderObject() as RenderBox?;
      if (mounted && box != null && box.hasSize) {
        setState(() => _fitted = box.size.height);
      }
    });
  }

  @override
  void didChangeMetrics() {
    final view = View.of(context);
    final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
    if (keyboard != _keyboard) setState(() => _keyboard = keyboard);
  }

  late final TextEditingController _text = TextEditingController(
    text: widget.existing?.content ?? '',
  );
  late final TextEditingController _author = TextEditingController(
    text: widget.existing?.author ?? '',
  );
  late MoodboardQuoteStyle _style =
      widget.existing?.quoteStyle ?? MoodboardQuoteStyle.celestial;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    _author.dispose();
    super.dispose();
  }

  String _styleLabel(MoodboardQuoteStyle style) {
    final strings = context.strings;
    return switch (style) {
      MoodboardQuoteStyle.celestial => strings.moodboardQuoteStyleCelestial,
      MoodboardQuoteStyle.aurora => strings.moodboardQuoteStyleAurora,
      MoodboardQuoteStyle.editorial => strings.moodboardQuoteStyleEditorial,
      MoodboardQuoteStyle.constellation =>
        strings.moodboardQuoteStyleConstellation,
      MoodboardQuoteStyle.minimal => strings.moodboardQuoteStyleMinimal,
    };
  }

  /// Needs some text, and for an existing quote, an actual change.
  bool get _canSave {
    final text = _text.text.trim();
    if (text.isEmpty) return false;
    final existing = widget.existing;
    if (existing == null) return true;
    return text != existing.content ||
        _author.text.trim() != existing.author ||
        _style != existing.quoteStyle;
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_QuoteDraft(text: text, author: _author.text.trim(), style: _style));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final fitted = _fitted;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SizedBox(
        height: fitted,
        child: AppSheetFrame(
          key: _frameKey,
          expandChild: fitted != null,
          title: AppSheetTitle(strings.moodboardQuote),
          footerDivider: false,
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: AppButtonLabel(strings.cancel, color: colors.muted),
              ),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: Listenable.merge([_text, _author]),
                builder: (context, _) => ElevatedButton(
                  onPressed: _canSave ? _save : null,
                  child: AppButtonLabel(strings.saveChanges),
                ),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + _keyboard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.moodboardQuoteDescription,
                  style: TextStyle(color: colors.muted),
                ),
                const SizedBox(height: 16),
                AppFieldLabel(
                  strings.moodboardQuoteTextLabel,
                  requirement: FieldRequirement.required,
                  counterController: _text,
                  counterMax: _kQuoteMaxLength,
                ),
                const SizedBox(height: kFieldLabelGap),
                AppTextField(
                  key: const ValueKey('quote-text-field'),
                  controller: _text,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: _kQuoteMaxLength,
                  showCounter: false,
                ),
                const SizedBox(height: 16),
                AppFieldLabel(
                  strings.moodboardQuoteAuthorLabel,
                  requirement: FieldRequirement.optional,
                  counterController: _author,
                  counterMax: _kQuoteAuthorMaxLength,
                ),
                const SizedBox(height: kFieldLabelGap),
                AppTextField(
                  key: const ValueKey('quote-author-field'),
                  controller: _author,
                  maxLength: _kQuoteAuthorMaxLength,
                  showCounter: false,
                  hintText: strings.moodboardQuoteAuthorHint,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                AppFieldLabel(
                  strings.moodboardQuoteStyleLabel,
                  requirement: FieldRequirement.required,
                ),
                const SizedBox(height: kFieldLabelGap + 4),
                SizedBox(
                  height: 172,
                  // The previews are fixed samples, not the text being typed.
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: MoodboardQuoteStyle.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final style = MoodboardQuoteStyle.values[index];
                      final selected = style == _style;
                      return Semantics(
                        button: true,
                        selected: selected,
                        label: _styleLabel(style),
                        child: InkWell(
                          key: ValueKey('quote-style-${style.name}'),
                          onTap: () => setState(() => _style = style),
                          borderRadius: BorderRadius.circular(14),
                          splashFactory: NoSplash.splashFactory,
                          highlightColor: Colors.transparent,
                          child: SizedBox(
                            width: 116,
                            child: Column(
                              children: [
                                Expanded(
                                  // The card never changes size or radius; the
                                  // border is painted over it, so selecting a
                                  // style cannot shift anything inside.
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: MoodboardQuoteCard(
                                          item: MoodboardItem(
                                            id: 'preview',
                                            kind: MoodboardKind.quote,
                                            content: strings
                                                .moodboardQuoteSampleText,
                                            author: strings
                                                .moodboardQuoteSampleAuthor,
                                            quoteStyle: style,
                                          ),
                                        ),
                                      ),
                                      IgnorePointer(
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: selected
                                                  ? colors.gold
                                                  : colors.nightBorder,
                                              width: selected ? 2 : 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _styleLabel(style),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? colors.gold
                                        : colors.muted,
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
