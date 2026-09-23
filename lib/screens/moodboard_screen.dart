import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/moodboard_repository.dart';
import '../data/moodboard_storage.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../utils/responsive.dart';
import '../widgets/area_section_header.dart';
import '../widgets/moodboard_grid.dart';
import '../widgets/responsive_content.dart';

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
    final controller = TextEditingController(text: existing?.content ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.moodboardQuote),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: 1000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.strings.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(context.strings.saveChanges),
          ),
        ],
      ),
    );
    // The dialog's closing animation can still use the controller.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final item = MoodboardItem(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        kind: MoodboardKind.quote,
        content: result,
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
            appBar: AppBar(
              title: Text(context.strings.moodboardTitle),
              actions: [
                if (item.kind == MoodboardKind.quote)
                  IconButton(
                    tooltip: context.strings.moodboardEdit,
                    onPressed: () => Navigator.pop(context, 'edit'),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                IconButton(
                  tooltip: context.strings.moodboardRemove,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(
                          dialogContext.strings.moodboardRemoveConfirm,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: Text(dialogContext.strings.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: Text(dialogContext.strings.moodboardRemove),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      Navigator.pop(context, 'delete');
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            body: SafeArea(
              child: item.kind == MoodboardKind.quote
                  ? SingleChildScrollView(
                      child: MoodboardMedia(item: item, expanded: true),
                    )
                  : MoodboardMedia(item: item, expanded: true),
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
        label: Text(strings.photoLabel),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _addMedia(MoodboardKind.video),
        icon: const Icon(Icons.video_library_outlined),
        label: Text(strings.moodboardVideo),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _quote,
        icon: const Icon(Icons.format_quote),
        label: Text(strings.moodboardQuote),
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 20,
        scrolledUnderElevation: 20,
        shadowColor: Colors.black,
        title: Text(widget.area.displayName(strings)),
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
            children: [
              if (_busy) const LinearProgressIndicator(color: Colors.white),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AreaSectionHeader(
                        title: strings.moodboardTitle,
                        description: strings.moodboardPageDescription,
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          strings.moodboardAddLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isTouchOnlyMobile)
                        SizedBox(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: addActions,
                          ),
                        )
                      else
                        Center(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: addActions,
                          ),
                        ),
                      const SizedBox(height: 20),
                      MoodboardGrid(
                        items: _items,
                        onTap: _busy ? null : _open,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
