import 'package:file_picker/file_picker.dart';
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

/// Extensions offered when attaching a document.
const _documentExtensions = [
  'pdf',
  'doc',
  'docx',
  'txt',
  'rtf',
  'odt',
  'xls',
  'xlsx',
  'csv',
  'ppt',
  'pptx',
];

/// The optional "Memories" part of a victory's form: one individual field
/// per kind of extra (voice notes, more photos, videos, documents, links),
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

  int get _remaining => kMaxStarMedia - media.length;

  bool _checkLimit(BuildContext context) {
    if (_remaining > 0) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.mediaLimitReached(kMaxStarMedia))),
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
    if (!_checkLimit(context)) return;
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
    if (!_checkLimit(context)) return;
    final source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    try {
      final picker = ImagePicker();
      final List<XFile> picked;
      if (source == ImageSource.camera || _remaining == 1) {
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
          limit: _remaining,
        );
      }
      if (picked.isEmpty) return;
      final items = <StarMedia>[];
      for (final file in picked.take(_remaining)) {
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
    if (!_checkLimit(context)) return;
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
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

  Future<void> _addDocument(BuildContext context) async {
    if (!_checkLimit(context)) return;
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _documentExtensions,
      );
      if (picked == null) return;
      final path = await StarMediaStorage.save(picked.xFile, name: picked.name);
      _addAll([
        StarMedia(
          id: _newId(0),
          kind: StarMediaKind.document,
          path: path,
          label: picked.name,
          createdAt: DateTime.now(),
        ),
      ]);
    } catch (error) {
      debugPrint('Adding a document failed: $error');
      if (context.mounted) _showError(context);
    }
  }

  Future<void> _addLink(BuildContext context) async {
    if (!_checkLimit(context)) return;
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    List<StarMedia> of(StarMediaKind kind) =>
        media.where((m) => m.kind == kind).toList();
    final canAdd = media.length < kMaxStarMedia;

    final fields = <Widget>[
      _ExtraField(
        label: strings.voiceNotesLabel,
        hint: strings.addVoiceNoteHint,
        icon: Icons.mic_none_rounded,
        canAdd: canAdd,
        onAdd: () => _addVoice(context),
        items: [
          for (final item in of(StarMediaKind.voice))
            _RemovableRow(
              key: ValueKey(item.id),
              onRemove: () => _remove(item),
              child: VoiceNotePlayer(media: item, framed: false),
            ),
        ],
      ),
      _ExtraField(
        label: strings.extraPhotosLabel,
        hint: strings.addExtraPhotosHint,
        icon: Icons.add_photo_alternate_outlined,
        canAdd: canAdd,
        onAdd: () => _addPhotos(context),
        items: [_PhotoGrid(photos: of(StarMediaKind.photo), onRemove: _remove)],
        hasItems: of(StarMediaKind.photo).isNotEmpty,
      ),
      _ExtraField(
        label: strings.videosLabel,
        hint: strings.addVideoHint,
        icon: Icons.videocam_outlined,
        canAdd: canAdd,
        onAdd: () => _addVideo(context),
        items: [
          for (final item in of(StarMediaKind.video))
            _RemovableRow(
              key: ValueKey(item.id),
              onRemove: () => _remove(item),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showStarMediaViewer(context, [item], 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StarMediaTile(media: item, size: 56),
                      const SizedBox(width: 12),
                      Text(
                        strings.extraVideo,
                        style: TextStyle(color: colors.muted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      _ExtraField(
        label: strings.documentsLabel,
        hint: strings.addDocumentHint,
        icon: Icons.attach_file_rounded,
        canAdd: canAdd,
        onAdd: () => _addDocument(context),
        items: [
          for (final item in of(StarMediaKind.document))
            _RemovableRow(
              key: ValueKey(item.id),
              onRemove: () => _remove(item),
              child: _LeadingText(
                icon: Icons.description_outlined,
                text: documentDisplayText(item),
              ),
            ),
        ],
      ),
      _ExtraField(
        label: strings.linksLabel,
        hint: strings.addLinkHint,
        icon: Icons.link_rounded,
        canAdd: canAdd,
        onAdd: () => _addLink(context),
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
        Text(
          strings.extrasLabel,
          style: TextStyle(
            color: colors.gold,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          fields[i],
        ],
      ],
    );
  }
}

/// One kind of extra as its own field: a label, then a dark panel that is
/// an "add" prompt while empty and holds the items (plus another "add" line)
/// once it isn't.
class _ExtraField extends StatelessWidget {
  const _ExtraField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.canAdd,
    required this.onAdd,
    required this.items,
    bool? hasItems,
  }) : _hasItems = hasItems ?? items.length > 0;

  final String label;
  final String hint;
  final IconData icon;
  final bool canAdd;
  final VoidCallback onAdd;
  final List<Widget> items;
  final bool _hasItems;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final addRow = InkWell(
      onTap: canAdd ? onAdd : null,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _hasItems ? 10 : 6),
        child: Row(
          mainAxisAlignment: _hasItems
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(
              _hasItems ? Icons.add_rounded : icon,
              color: colors.muted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(hint, style: TextStyle(color: colors.muted, fontSize: 14)),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label, requirement: FieldRequirement.optional),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: fieldDecoration(
            colors,
            _hasItems ? FieldState.filled : FieldState.empty,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [...items, if (!_hasItems || canAdd) addRow],
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
            icon: Icon(Icons.close_rounded, color: colors.muted, size: 20),
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

/// Thumbnails of the extra photos, each with its own small remove button.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onRemove});

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
                    child: StarMediaTile(media: photo),
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
                          border: Border.all(color: colors.nightBorder),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: colors.muted,
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
