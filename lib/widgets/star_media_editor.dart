import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/star_media_storage.dart';
import '../l10n/strings_scope.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'app_field.dart';
import 'memory_field_actions.dart';
import 'photo_picker.dart' show showPhotoSourceSheet;
import 'star_media_views.dart';
import 'voice_note_player.dart';
import 'voice_note_recorder_sheet.dart';

/// The optional memories part of a victory's form: one individual field
/// per kind of extra (voice notes, more photos, videos, links),
/// each holding its own items and a way to add another. Reports every
/// change through [onChanged]; the form decides what to do with files
/// whose items got removed.
class StarMediaEditor extends StatelessWidget {
  const StarMediaEditor({
    super.key,
    required this.media,
    required this.onChanged,
    this.kinds = StarMediaKind.values,
    this.compact = false,
    this.gridHeight,
  });

  final List<StarMedia> media;
  final ValueChanged<List<StarMedia>> onChanged;

  /// Which kinds this instance shows, so the form can place photos apart
  /// from the rest; every instance edits the same [media] list.
  final List<StarMediaKind> kinds;

  /// Half-width layout: photos in two columns, no counter or length note.
  final bool compact;

  /// With [compact], the exact height the photo grid should fill.
  final double? gridHeight;

  int _countOf(StarMediaKind kind) => media.where((m) => m.kind == kind).length;

  int _remaining(StarMediaKind kind) =>
      kMaxStarMediaPerKind[kind]! - _countOf(kind);

  bool _checkLimit(BuildContext context, StarMediaKind kind) {
    if (_remaining(kind) > 0) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.strings.mediaLimitReached(kMaxStarMediaPerKind[kind]!),
        ),
      ),
    );
    return false;
  }

  void _addAll(List<StarMedia> items) => onChanged([...media, ...items]);

  static String _newId(int salt) =>
      '${DateTime.now().microsecondsSinceEpoch}$salt';

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.strings.mediaError)));
  }

  Future<void> _addVoice(BuildContext context) async {
    if (!_checkLimit(context, StarMediaKind.voice)) return;
    final recording = await showVoiceNoteRecorder(context);
    if (recording == null) return;
    _addAll([
      StarMedia(
        id: _newId(0),
        kind: StarMediaKind.voice,
        path: recording.path,
        durationMs: recording.durationMs,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  Future<void> _addPhotos(BuildContext context) async {
    if (!_checkLimit(context, StarMediaKind.photo)) return;
    final source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    try {
      final picker = ImagePicker();
      final List<XFile> picked;
      if (source == ImageSource.camera ||
          _remaining(StarMediaKind.photo) == 1) {
        final single = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          imageQuality: 85,
        );
        picked = single == null ? const [] : [single];
      } else {
        // The picker only honors a limit of 2 or more; anything past what's
        // still free is dropped below either way.
        picked = await picker.pickMultiImage(
          maxWidth: 1600,
          imageQuality: 85,
          limit: _remaining(StarMediaKind.photo),
        );
      }
      if (picked.isEmpty) return;
      final items = <StarMedia>[];
      for (final file in picked.take(_remaining(StarMediaKind.photo))) {
        final path = await StarMediaStorage.save(
          file,
          fallbackExtension: 'jpg',
        );
        items.add(
          StarMedia(
            id: _newId(items.length),
            kind: StarMediaKind.photo,
            path: path,
            createdAt: DateTime.now(),
          ),
        );
      }
      _addAll(items);
    } catch (_) {
      if (context.mounted) _showError(context);
    }
  }

  Future<void> _addVideo(BuildContext context) async {
    if (!_checkLimit(context, StarMediaKind.video)) return;
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: kMaxVideoDuration,
      );
      if (picked == null) return;
      final path = await StarMediaStorage.save(
        picked,
        fallbackExtension: 'mp4',
      );
      _addAll([
        StarMedia(
          id: _newId(0),
          kind: StarMediaKind.video,
          path: path,
          createdAt: DateTime.now(),
        ),
      ]);
    } catch (_) {
      if (context.mounted) _showError(context);
    }
  }

  Future<void> _addLink(BuildContext context) async {
    if (!_checkLimit(context, StarMediaKind.link)) return;
    final result = await showAppDialog<({String url, String? label})>(
      context: context,
      builder: (_) => const _LinkDialog(),
    );
    if (result == null) return;
    _addAll([
      StarMedia(
        id: _newId(0),
        kind: StarMediaKind.link,
        url: result.url,
        label: result.label,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  void _remove(StarMedia item) => onChanged([
    for (final m in media)
      if (m != item) m,
  ]);

  /// Drops every item of [kind] and leaves the other kinds as they were.
  void _reset(StarMediaKind kind) => onChanged([
    for (final m in media)
      if (m.kind != kind) m,
  ]);

  /// Below this width (a phone) voice notes and links stack at full width
  /// instead of sharing a row.
  static const _pairedMinWidth = 520.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _content(context, wide: constraints.maxWidth >= _pairedMinWidth),
    );
  }

  Widget _content(BuildContext context, {required bool wide}) {
    final strings = context.strings;
    final colors = context.colors;
    List<StarMedia> of(StarMediaKind kind) =>
        media.where((m) => m.kind == kind).toList();

    // Voice notes and links sit side by side, half the width each, whenever
    // one instance shows both and there is room.
    final paired =
        wide &&
        !compact &&
        kinds.contains(StarMediaKind.voice) &&
        kinds.contains(StarMediaKind.link);

    final fields = <_ExtraField>[
      _ExtraField(
        label: strings.extraPhotosLabel,
        kind: StarMediaKind.photo,
        compact: compact,
        count: _countOf(StarMediaKind.photo),
        onReset: () => _reset(StarMediaKind.photo),
        zone: _MediaTileGrid(
          items: of(StarMediaKind.photo),
          perRow: compact ? 2 : 5,
          fitHeight: gridHeight,
          onRemove: _remove,
          ghosts: _remaining(StarMediaKind.photo),
          ghostIcon: Icons.image_outlined,
          onGhostTap: () => _addPhotos(context),
        ),
      ),
      _ExtraField(
        label: strings.videosLabel,
        kind: StarMediaKind.video,
        compact: compact,
        count: _countOf(StarMediaKind.video),
        lengthNote: strings.mediaMaxDuration(
          formatVoiceDuration(kMaxVideoDuration),
        ),
        onReset: () => _reset(StarMediaKind.video),
        zone: _MediaTileGrid(
          items: of(StarMediaKind.video),
          onRemove: _remove,
          badgeColor: colors.gold,
          perRow: compact ? 2 : 5,
          ghosts: _remaining(StarMediaKind.video),
          ghostIcon: Icons.movie_outlined,
          onGhostTap: () => _addVideo(context),
        ),
      ),
      _ExtraField(
        label: strings.voiceNotesLabel,
        kind: StarMediaKind.voice,
        compact: compact,
        count: _countOf(StarMediaKind.voice),
        lengthNote: strings.mediaMaxDuration(
          formatVoiceDuration(kMaxVoiceNote),
        ),
        onReset: () => _reset(StarMediaKind.voice),
        zone: Column(
          children: [
            for (final item in of(StarMediaKind.voice))
              _RemovableRow(
                key: ValueKey(item.id),
                onRemove: () => _remove(item),
                child: VoiceNotePlayer(
                  media: item,
                  framed: false,
                  accent: colors.gold,
                  badgeSize: 16,
                  timeSize: 12,
                  timeInset: 5,
                  contentColor: Colors.white,
                  timeColor: colors.gold,
                ),
              ),
            for (var i = 0; i < _remaining(StarMediaKind.voice); i++)
              _KindPlaceholder(
                kind: StarMediaKind.voice,
                onTap: () => _addVoice(context),
              ),
          ],
        ),
      ),
      _ExtraField(
        label: strings.linksLabel,
        kind: StarMediaKind.link,
        compact: compact,
        count: _countOf(StarMediaKind.link),
        onReset: () => _reset(StarMediaKind.link),
        zone: Column(
          children: [
            for (final item in of(StarMediaKind.link))
              _RemovableRow(
                key: ValueKey(item.id),
                onRemove: () => _remove(item),
                onTap: () => openExtraLink(context, item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: _LeadingText(
                    icon: Icons.link_rounded,
                    text: linkDisplayText(item),
                  ),
                ),
              ),
            for (var i = 0; i < _remaining(StarMediaKind.link); i++)
              _KindPlaceholder(
                kind: StarMediaKind.link,
                onTap: () => _addLink(context),
              ),
          ],
        ),
      ),
    ];

    final shown = [
      for (final field in fields)
        if (kinds.contains(field.kind)) field,
    ];

    // The voice-note and link fields collapse into one row, placed where the
    // voice-note field was.
    final sections = <Widget>[];
    for (final field in shown) {
      if (paired && field.kind == StarMediaKind.link) continue;
      if (paired && field.kind == StarMediaKind.voice) {
        final link = shown.firstWhere((f) => f.kind == StarMediaKind.link);
        sections.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 12),
              Expanded(child: link),
            ],
          ),
        );
      } else {
        sections.add(field);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          sections[i],
        ],
      ],
    );
  }
}

/// One kind of extra as its own field: a label row (limits on the right,
/// the length limit centered), a zone with no panel of its own holding the
/// real items followed by a faint placeholder for every slot still free,
/// and, below it, the centered Reset/Add pair.
class _ExtraField extends StatelessWidget {
  const _ExtraField({
    required this.label,
    required this.kind,
    required this.count,
    required this.onReset,
    required this.zone,
    this.compact = false,
    this.lengthNote,
  });

  final String label;
  final StarMediaKind kind;

  /// How many of this kind are added; the label row shows it against the
  /// kind's own maximum, right-aligned.
  final int count;

  /// The longest a single item may be, as a centered caption under the zone.
  final String? lengthNote;
  final VoidCallback onReset;
  final Widget zone;

  /// Half-width column: no name row, no length note.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final note = lengthNote;
    if (compact) {
      // A half-width column of a shared section: no name row of its own, the
      // name is a discreet caption under the zone.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [zone, MemoryCaption(label)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppFieldLabel(label, requirement: FieldRequirement.optional),
            MemoryResetButton(onReset: onReset, canReset: count > 0),
          ],
        ),
        const SizedBox(height: kFieldLabelGap),
        zone,
        if (note != null) MemoryCaption(note),
      ],
    );
  }
}

class _RemovableRow extends StatelessWidget {
  const _RemovableRow({
    super.key,
    required this.child,
    required this.onRemove,
    this.onTap,
  });

  final Widget child;

  /// Tapping anywhere on the tile (but its remove badge).
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: DecoratedBox(
              decoration: _tileBody(colors),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _kTileHeight),
                child: Center(child: child),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Tooltip(
              message: context.strings.removeExtraTooltip,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: _MediaTileGrid._closeBadge(colors),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadingText extends StatelessWidget {
  const _LeadingText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Center(child: Icon(icon, color: colors.gold, size: 16)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.text, fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        // Same slot as the icon on the left, so the text stays centered on the
        // whole tile.
        SizedBox(
          width: 26,
          height: 26,
          child: Center(
            child: Icon(
              Icons.open_in_new_rounded,
              color: colors.gold,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Thumbnails of photo or video extras in a row that wraps, each with its own
/// small remove button in the top-right corner, followed by a faint
/// placeholder tile for each of the [ghosts] slots still free.
class _MediaTileGrid extends StatelessWidget {
  const _MediaTileGrid({
    required this.items,
    required this.onRemove,
    required this.ghosts,
    required this.ghostIcon,
    required this.onGhostTap,
    required this.perRow,
    this.fitHeight,
    this.badgeColor = Colors.white,
  });

  final List<StarMedia> items;
  final ValueChanged<StarMedia> onRemove;
  final int ghosts;
  final IconData ghostIcon;

  /// Tapping a free slot adds one: the placeholders are the add button.
  final VoidCallback onGhostTap;

  final int perRow;

  /// When set, the grid is exactly this tall (see [StarMediaEditor.gridHeight]).
  final double? fitHeight;
  final Color badgeColor;

  static const _gap = 8.0;

  static Widget _closeBadge(AppColors colors) =>
      RemoveBadge(background: colors.nightPanel);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = fitHeight;
        final rows = ((items.length + ghosts) / perRow).ceil().clamp(1, 99);
        // Floored so rounding can never push the last tile of a row onto a
        // new one. With [fitHeight] the tiles stay as wide as the columns
        // allow but take whatever height makes the rows fill that height
        // exactly, so they are no longer square.
        final tileW = ((constraints.maxWidth - (perRow - 1) * _gap) / perRow)
            .floorToDouble();
        final tileH = fit != null ? (fit - (rows - 1) * _gap) / rows : tileW;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: fit != null ? 0 : 4),
          child: Wrap(
            alignment: fit != null
                ? WrapAlignment.spaceBetween
                : WrapAlignment.start,
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final item in items)
                SizedBox(
                  key: ValueKey(item.id),
                  width: tileW,
                  height: tileH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => showStarMediaViewer(
                          context,
                          items,
                          items.indexOf(item),
                        ),
                        child: StarMediaTile(
                          media: item,
                          size: tileW,
                          height: tileH,
                          badgeColor: badgeColor,
                          badgeSize: 28,
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: InkWell(
                          onTap: () => onRemove(item),
                          customBorder: const CircleBorder(),
                          child: _closeBadge(colors),
                        ),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < ghosts; i++)
                Semantics(
                  button: true,
                  label: context.strings.addExtraAction,
                  child: InkWell(
                    onTap: onGhostTap,
                    borderRadius: BorderRadius.circular(kRadiusField),
                    child: Container(
                      width: tileW,
                      height: tileH,
                      decoration: BoxDecoration(
                        color: colors.nightPanel,
                        borderRadius: BorderRadius.circular(kRadiusField),
                        border: Border.all(color: colors.nightBorder),
                      ),
                      alignment: Alignment.center,
                      child: Icon(ghostIcon, color: colors.muted, size: 30),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Link entry as a dialog (not a bottom sheet) so it moves clear of the
/// keyboard by itself.
class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _url = TextEditingController();
  final _label = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final uri = parseExtraLink(_url.text);
    if (uri == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop((url: uri.toString(), label: _label.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    return AppDialog(
      scrollable: true,
      actionsAlignment: MainAxisAlignment.center,
      // Top matches the 16 between title and first field, bottom the 24
      // above the title.
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      title: Text(strings.linkTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFieldLabel(
            strings.linkUrlLabel,
            requirement: FieldRequirement.required,
            counterController: _url,
            counterMax: kMaxLinkUrlLength,
          ),
          const SizedBox(height: kFieldLabelGap),
          AppTextField(
            controller: _url,
            maxLength: kMaxLinkUrlLength,
            showCounter: false,
            hintText: strings.linkUrlHint,
            textInputAction: TextInputAction.next,
            errorText: _invalid ? strings.linkInvalid : null,
            onChanged: (_) => setState(() => _invalid = false),
          ),
          const SizedBox(height: 16),
          AppFieldLabel(
            strings.linkLabelLabel,
            requirement: FieldRequirement.required,
            counterController: _label,
            counterMax: kMaxLinkLabelLength,
          ),
          const SizedBox(height: kFieldLabelGap),
          AppTextField(
            controller: _label,
            maxLength: kMaxLinkLabelLength,
            showCounter: false,
            hintText: strings.linkLabelHint,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: AppButtonLabel(strings.cancel, color: colors.muted),
        ),
        ElevatedButton(
          onPressed: _url.text.trim().isEmpty || _label.text.trim().isEmpty
              ? null
              : _submit,
          // Off, it keeps a visible button background (the theme's off
          // colour is the dialog's own, so it would vanish).
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: colors.nightBorder,
            disabledForegroundColor: colors.muted,
          ),
          child: AppButtonLabel(strings.linkAdd),
        ),
      ],
    );
  }
}

/// A free voice-note or link slot: drawn like a real row (the same pill,
/// play mark, bars and length, or link mark and line of text, and the same
/// remove button position) but faint and flat, so it reads as a stand-in.
class _KindPlaceholder extends StatelessWidget {
  const _KindPlaceholder({required this.kind, required this.onTap});

  final StarMediaKind kind;

  /// Tapping the stand-in adds one: the placeholder is the add button.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ghost = colors.muted;
    final fill = _tileBody(colors);
    final Widget shape = switch (kind) {
      StarMediaKind.voice => Container(
        decoration: fill,
        constraints: const BoxConstraints(minHeight: _kTileHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            // Same 26 px slot as the play badge of a real voice note, so the
            // bars and length start at the same place.
            SizedBox(
              width: 26,
              height: 26,
              child: Center(
                child: Icon(Icons.mic_none_outlined, size: 16, color: ghost),
              ),
            ),
            const SizedBox(width: 50),
            Expanded(
              child: SizedBox(
                height: 18,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final count = ((constraints.maxWidth + 3) / 6).floor();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < count; i++)
                          Container(
                            width: 3,
                            height: 18 * (0.25 + (i * 37 % 10) / 14),
                            decoration: BoxDecoration(
                              color: ghost,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 50),
            // Same 5 px after the length as a real note (timeInset).
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Text(
                '0:00',
                maxLines: 1,
                style: TextStyle(
                  color: ghost,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
      _ => Container(
        decoration: fill,
        constraints: const BoxConstraints(minHeight: _kTileHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: Center(
                child: Icon(Icons.link_rounded, color: ghost, size: 16),
              ),
            ),
            const SizedBox(width: 50),
            // Spans the same stretch as a voice note's bars, centered.
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: ghost,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 50),
            SizedBox(
              width: 26,
              height: 26,
              child: Center(
                child: Icon(Icons.open_in_new_rounded, color: ghost, size: 16),
              ),
            ),
          ],
        ),
      ),
    };
    // No remove button on a stand-in, but its width is held so it lines up
    // with the real rows beside it.
    return Semantics(
      button: true,
      label: context.strings.addExtraAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusField),
          child: shape,
        ),
      ),
    );
  }
}

/// As tall as the single-line fields above (a picker field: 12 of padding
/// either side of a ~21 px line of text, plus its 1.5 px border each side).
const double _kTileHeight = 48;

/// The body every voice-note and link row shares, real or placeholder: a
/// plain field-colored tile with the field border.
BoxDecoration _tileBody(AppColors colors) => BoxDecoration(
  color: colors.nightPanel,
  borderRadius: BorderRadius.circular(kRadiusField),
  border: Border.all(color: colors.nightBorder),
);
