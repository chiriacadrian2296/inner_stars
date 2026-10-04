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
import '../utils/responsive.dart';
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
    String? path;
    var saved = false;
    try {
      final picker = ImagePicker();
      final file = kind == MoodboardKind.photo
          ? await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 2400,
              imageQuality: 90,
            )
          : await picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      path = await MoodboardStorage.save(file);
      await widget.repository.save(widget.area, [
        ..._items,
        MoodboardItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          kind: kind,
          content: path,
        ),
      ]);
      saved = true;
    } catch (_) {
      _error();
    } finally {
      if (!saved && path != null) {
        try {
          await MoodboardStorage.delete(path);
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quote([MoodboardItem? existing]) async {
    final result = await showAppSheet<_QuoteDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: kResponsiveContentMaxWidth,
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
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
            backgroundColor: Colors.black,
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
    final addActions = <Widget>[
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _addMedia(MoodboardKind.photo),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: AppButtonLabel(strings.photoLabel),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _addMedia(MoodboardKind.video),
        icon: const Icon(Icons.video_library_outlined),
        label: AppButtonLabel(strings.moodboardVideo),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _quote,
        icon: const Icon(Icons.format_quote),
        label: AppButtonLabel(strings.moodboardQuote),
      ),
    ];
    // Side by side, so they slide in from the side rather than rising.
    final sideBySideActions = StaggeredEntrance.all(
      addActions,
      start: 2,
      axis: Axis.horizontal,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              // Keep the mark inside the canvas that begins below the
              // heading and the add-media controls.
              top: 220,
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
                top: 220,
                bottom: 0,
                child: Center(
                  child: StaggeredEntrance(
                    index: 4,
                    child: Text(
                      strings.moodboardEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ResponsiveContent(
              child: Column(
                children: [
                  if (_busy) const LinearProgressIndicator(color: Colors.white),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StaggeredEntrance(
                            index: 0,
                            child: AreaSectionHeader(
                              title:
                                  '${strings.moodboardTitle} - ${widget.area.displayName(strings)}',
                              description: strings.moodboardPageDescription,
                            ),
                          ),
                          const SizedBox(height: 24),
                          StaggeredEntrance(
                            index: 1,
                            child: Center(
                              child: Text(
                                strings.moodboardAddLabel,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (isTouchOnlyMobile)
                            SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  for (
                                    var i = 0;
                                    i < sideBySideActions.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    Expanded(child: sideBySideActions[i]),
                                  ],
                                ],
                              ),
                            )
                          else
                            Center(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: sideBySideActions,
                              ),
                            ),
                          const SizedBox(height: 20),
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
                  StaggeredEntrance(
                    index: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: _busy ? null : _share,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                          ),
                          icon: const Icon(Icons.share_outlined),
                          label: AppButtonLabel(
                            strings.starQuickLookShareAction,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

class _QuoteEditorSheetState extends State<_QuoteEditorSheet> {
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
    final previewText = _text.text.trim().isEmpty
        ? strings.moodboardQuoteDescription
        : _text.text.trim();
    return AppSheetFrame(
      title: AppSheetTitle(strings.moodboardQuote),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: AppButtonLabel(strings.cancel),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _text,
            builder: (context, value, _) => ElevatedButton(
              onPressed: value.text.trim().isEmpty ? null : _save,
              child: AppButtonLabel(strings.saveChanges),
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.moodboardQuoteDescription,
              style: TextStyle(color: colors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('quote-text-field'),
              controller: _text,
              autofocus: widget.existing == null,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: strings.moodboardQuoteTextLabel,
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('quote-author-field'),
              controller: _author,
              maxLines: 1,
              maxLength: 100,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: strings.moodboardQuoteAuthorLabel,
                hintText: strings.moodboardQuoteAuthorHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              strings.moodboardQuoteStyleLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 172,
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
                      child: SizedBox(
                        width: 116,
                        child: Column(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? colors.gold
                                        : colors.nightBorder,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: MoodboardQuoteCard(
                                  item: MoodboardItem(
                                    id: 'preview',
                                    kind: MoodboardKind.quote,
                                    content: previewText,
                                    author: _author.text.trim(),
                                    quoteStyle: style,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _styleLabel(style),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? colors.gold : colors.muted,
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
    );
  }
}
