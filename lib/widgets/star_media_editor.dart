import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/star_media_storage.dart';
import '../l10n/strings_scope.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'app_field.dart';
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
        hint: strings.addExtraPhotosHint,
        icon: Icons.add_photo_alternate_outlined,
        onAdd: () => _addPhotos(context),
        onReset: () => _reset(StarMediaKind.photo),
        items: [
          _MediaTileGrid(photos: of(StarMediaKind.photo), onRemove: _remove),
        ],
        hasItems: of(StarMediaKind.photo).isNotEmpty,
      ),
      _ExtraField(
        label: strings.videosLabel,
        kind: StarMediaKind.video,
        count: _countOf(StarMediaKind.video),
        hint: strings.addVideoHint,
        lengthNote: strings.mediaMaxDuration(
          formatVoiceDuration(kMaxVideoDuration),
        ),
        icon: Icons.videocam_outlined,
        onAdd: () => _addVideo(context),
        onReset: () => _reset(StarMediaKind.video),
        items: [
          _MediaTileGrid(
            photos: of(StarMediaKind.video),
            onRemove: _remove,
            badgeColor: colors.gold,
          ),
        ],
        hasItems: of(StarMediaKind.video).isNotEmpty,
      ),
      _ExtraField(
        label: strings.voiceNotesLabel,
        kind: StarMediaKind.voice,
        count: _countOf(StarMediaKind.voice),
        hint: strings.addVoiceNoteHint,
        lengthNote: strings.mediaMaxDuration(
          formatVoiceDuration(kMaxVoiceNote),
        ),
        icon: Icons.mic_none_rounded,
        onAdd: () => _addVoice(context),
        onReset: () => _reset(StarMediaKind.voice),
        items: [
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
        ],
      ),
      _ExtraField(
        label: strings.linksLabel,
        kind: StarMediaKind.link,
        count: _countOf(StarMediaKind.link),
        hint: strings.addLinkHint,
        icon: Icons.link_rounded,
        onAdd: () => _addLink(context),
        onReset: () => _reset(StarMediaKind.link),
        items: [
          for (final item in of(StarMediaKind.link))
            _RemovableRow(
              key: ValueKey(item.id),
              onRemove: () => _remove(item),
              child: _LeadingText(
                icon: Icons.link_rounded,
                text: linkDisplayText(item),
              ),
            ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          fields[i],
        ],
      ],
    );
  }
}

/// One kind of extra as its own field: a label (with a reset for just this
/// kind once it holds something), an "add" button that always looks the
/// same, and, below it and apart from it, a panel previewing what's been
/// added so far. The panel grows with its content.
class _ExtraField extends StatelessWidget {
  const _ExtraField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.kind,
    required this.count,
    required this.onAdd,
    required this.onReset,
    required this.items,
    this.lengthNote,
    bool? hasItems,
  }) : _hasItems = hasItems ?? items.length > 0;

  final String label;
  final String hint;
  final StarMediaKind kind;

  /// How many of this kind are added; the label row shows it against the
  /// kind's own maximum, right-aligned.
  final int count;

  /// The longest a single item may be, centered on the label row.
  final String? lengthNote;
  final IconData icon;
  final VoidCallback onAdd;
  final VoidCallback onReset;
  final List<Widget> items;
  final bool _hasItems;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final note = lengthNote;
    final max = kMaxStarMediaPerKind[kind]!;
    final canAdd = count < max;
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
        const SizedBox(height: 6),
        ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: fieldDecoration(
              colors,
              _hasItems ? FieldState.filled : FieldState.empty,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Empty, the panel still stands: a faint stand-in for what
                // this kind will look like once something is added.
                if (_hasItems) ...items else _KindPlaceholder(kind: kind),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: _hasItems ? onReset : null,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.gold,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: AppButtonLabel(
                      context.strings.resetExtraAction,
                      color: colors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Opacity(
          opacity: canAdd ? 1 : 0.5,
          child: InkWell(
            onTap: canAdd ? onAdd : null,
            borderRadius: BorderRadius.circular(kRadiusField),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: fieldDecoration(colors, FieldState.empty),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: colors.muted, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    hint,
                    style: TextStyle(color: colors.muted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
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
/// small remove button in the top-right corner.
class _MediaTileGrid extends StatelessWidget {
  const _MediaTileGrid({
    required this.photos,
    required this.onRemove,
    this.badgeColor = Colors.white,
  });

  final Color badgeColor;

  final List<StarMedia> photos;
  final ValueChanged<StarMedia> onRemove;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final photo in photos)
            SizedBox(
              key: ValueKey(photo.id),
              width: 72,
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => showStarMediaViewer(
                      context,
                      photos,
                      photos.indexOf(photo),
                    ),
                    child: StarMediaTile(
                      media: photo,
                      badgeColor: badgeColor,
                      badgeSize: 28,
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: InkWell(
                      onTap: () => onRemove(photo),
                      customBorder: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.nightPanel,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.gold),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: colors.gold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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

/// What an empty panel shows in place of items: the shape of one item of
/// [kind], drawn faint and flat so it reads as a stand-in, never as content.
class _KindPlaceholder extends StatelessWidget {
  const _KindPlaceholder({required this.kind});

  final StarMediaKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ghost = colors.muted;
    final Widget shape = switch (kind) {
      StarMediaKind.photo || StarMediaKind.video => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadiusField),
          border: Border.all(color: ghost),
        ),
        child: Icon(
          kind == StarMediaKind.photo
              ? Icons.image_outlined
              : Icons.play_arrow_rounded,
          color: ghost,
          size: 30,
        ),
      ),
      StarMediaKind.voice => Row(
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 24; i++)
                  Container(
                    width: 3,
                    height: 5.0 + (i * 7 % 11),
                    decoration: BoxDecoration(
                      color: ghost,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('0:00', style: TextStyle(color: ghost, fontSize: 14)),
        ],
      ),
      StarMediaKind.link => Row(
        children: [
          Icon(Icons.link_rounded, color: ghost, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: ghost,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    };
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.3,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: shape,
          ),
        ),
      ),
    );
  }
}
