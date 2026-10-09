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
  });

  final List<StarMedia> media;
  final ValueChanged<List<StarMedia>> onChanged;

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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    List<StarMedia> of(StarMediaKind kind) =>
        media.where((m) => m.kind == kind).toList();

    final fields = <Widget>[
      _ExtraField(
        label: strings.extraPhotosLabel,
        kind: StarMediaKind.photo,
        count: _countOf(StarMediaKind.photo),
        icon: Icons.add_photo_alternate_outlined,
        onAdd: () => _addPhotos(context),
        onReset: () => _reset(StarMediaKind.photo),
        zone: _MediaTileGrid(
          items: of(StarMediaKind.photo),
          onRemove: _remove,
          ghosts: _remaining(StarMediaKind.photo),
          ghostIcon: Icons.image_outlined,
        ),
      ),
      _ExtraField(
        label: strings.videosLabel,
        kind: StarMediaKind.video,
        count: _countOf(StarMediaKind.video),
        lengthNote: strings.mediaMaxDuration(
          formatVoiceDuration(kMaxVideoDuration),
        ),
        icon: Icons.videocam_outlined,
        onAdd: () => _addVideo(context),
        onReset: () => _reset(StarMediaKind.video),
        zone: _MediaTileGrid(
          items: of(StarMediaKind.video),
          onRemove: _remove,
          badgeColor: colors.gold,
          ghosts: _remaining(StarMediaKind.video),
          ghostIcon: Icons.play_arrow_rounded,
        ),
      ),
      _ExtraField(
        label: strings.voiceNotesLabel,
        kind: StarMediaKind.voice,
        count: _countOf(StarMediaKind.voice),
        lengthNote: strings.mediaMaxDuration(
          formatVoiceDuration(kMaxVoiceNote),
        ),
        icon: Icons.mic_none_rounded,
        onAdd: () => _addVoice(context),
        onReset: () => _reset(StarMediaKind.voice),
        zone: _NarrowColumn(
          children: [
            for (final item in of(StarMediaKind.voice))
              _RemovableRow(
                key: ValueKey(item.id),
                onRemove: () => _remove(item),
                child: VoiceNotePlayer(
                  media: item,
                  framed: false,
                  accent: colors.gold,
                ),
              ),
            for (var i = 0; i < _remaining(StarMediaKind.voice); i++)
              const _KindPlaceholder(kind: StarMediaKind.voice),
          ],
        ),
      ),
      _ExtraField(
        label: strings.linksLabel,
        kind: StarMediaKind.link,
        count: _countOf(StarMediaKind.link),
        icon: Icons.link_rounded,
        onAdd: () => _addLink(context),
        onReset: () => _reset(StarMediaKind.link),
        zone: _NarrowColumn(
          children: [
            for (final item in of(StarMediaKind.link))
              _RemovableRow(
                key: ValueKey(item.id),
                onRemove: () => _remove(item),
                child: _LeadingText(
                  icon: Icons.link_rounded,
                  text: linkDisplayText(item),
                ),
              ),
            for (var i = 0; i < _remaining(StarMediaKind.link); i++)
              const _KindPlaceholder(kind: StarMediaKind.link),
          ],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          fields[i],
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
    required this.icon,
    required this.kind,
    required this.count,
    required this.onAdd,
    required this.onReset,
    required this.zone,
    this.lengthNote,
  });

  final String label;
  final StarMediaKind kind;

  /// How many of this kind are added; the label row shows it against the
  /// kind's own maximum, right-aligned.
  final int count;

  /// The longest a single item may be, centered on the label row.
  final String? lengthNote;
  final IconData icon;
  final VoidCallback onAdd;
  final VoidCallback onReset;
  final Widget zone;

  @override
  Widget build(BuildContext context) {
    final note = lengthNote;
    final max = kMaxStarMediaPerKind[kind]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                AppFieldLabel(label, requirement: FieldRequirement.optional),
                const Spacer(),
                Text('$count/$max', style: fieldLimitStyle(context)),
              ],
            ),
            if (note != null) Text(note, style: fieldLengthNoteStyle(context)),
          ],
        ),
        const SizedBox(height: 8),
        zone,
        const SizedBox(height: 12),
        MemoryFieldActions(
          addIcon: icon,
          onAdd: onAdd,
          onReset: onReset,
          canAdd: count < max,
          canReset: count > 0,
        ),
      ],
    );
  }
}

class _RemovableRow extends StatelessWidget {
  const _RemovableRow({super.key, required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: child),
          IconButton(
            tooltip: context.strings.removeExtraTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: colors.gold, size: 20),
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
        Icon(icon, color: colors.gold, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.text, fontSize: 14),
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
    this.badgeColor = Colors.white,
  });

  final List<StarMedia> items;
  final ValueChanged<StarMedia> onRemove;
  final int ghosts;
  final IconData ghostIcon;
  final Color badgeColor;

  static const _perRow = 5;
  static const _gap = 8.0;

  static Widget _closeBadge(AppColors colors) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: colors.nightPanel,
      shape: BoxShape.circle,
      border: Border.all(color: colors.gold),
    ),
    child: Icon(Icons.close_rounded, size: 14, color: colors.gold),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Floored so rounding can never push the fifth tile onto a new row.
        final tile = ((constraints.maxWidth - (_perRow - 1) * _gap) / _perRow)
            .floorToDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final item in items)
                SizedBox(
                  key: ValueKey(item.id),
                  width: tile,
                  height: tile,
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
                          size: tile,
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
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Container(
                      width: tile,
                      height: tile,
                      decoration: BoxDecoration(
                        color: colors.nightPanel,
                        borderRadius: BorderRadius.circular(kRadiusField),
                        border: Border.all(color: colors.nightBorder),
                      ),
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
    final label = _label.text.trim();
    Navigator.of(context)
        .pop((url: uri.toString(), label: label.isEmpty ? null : label));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AppDialog(
      scrollable: true,
      title: Text(strings.linkTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _url,
            autofocus: true,
            maxLength: kMaxLinkUrlLength,
            hintText: strings.linkUrlHint,
            textInputAction: TextInputAction.next,
            errorText: _invalid ? strings.linkInvalid : null,
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _label,
            maxLength: kMaxLinkLabelLength,
            hintText: strings.linkLabelHint,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: AppButtonLabel(strings.cancel),
        ),
        TextButton(onPressed: _submit, child: AppButtonLabel(strings.linkAdd)),
      ],
    );
  }
}

/// A free voice-note or link slot: drawn like a real row (the same pill,
/// play mark, bars and length, or link mark and line of text, and the same
/// remove button position) but faint and flat, so it reads as a stand-in.
class _KindPlaceholder extends StatelessWidget {
  const _KindPlaceholder({required this.kind});

  final StarMediaKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ghost = colors.muted;
    final fill = BoxDecoration(
      color: colors.nightPanel,
      borderRadius: BorderRadius.circular(kRadiusField),
      border: Border.all(color: colors.nightBorder),
    );
    final Widget shape = switch (kind) {
      StarMediaKind.voice => Container(
        decoration: fill,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ghost, width: 2),
              ),
              child: Icon(Icons.play_arrow_rounded, color: ghost, size: 14),
            ),
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
            Text(
              '0:00',
              style: TextStyle(
                color: ghost,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      _ => Container(
        decoration: fill,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.link_rounded, color: ghost, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: ghost,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    };
    // No remove button on a stand-in, but its width is held so it lines up
    // with the real rows beside it.
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: shape),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// The voice-note and link rows are short, so they sit centered in a
/// narrower column instead of stretching across the whole form.
class _NarrowColumn extends StatelessWidget {
  const _NarrowColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(children: children),
      ),
    );
  }
}
