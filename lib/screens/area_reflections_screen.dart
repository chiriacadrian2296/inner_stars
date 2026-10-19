import 'package:flutter/material.dart';

import '../data/reflection_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/reflection.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../utils/area_section_icons.dart';
import '../widgets/area_section_header.dart';
import '../widgets/responsive_content.dart';
import '../widgets/shareable_reflection_card.dart';
import 'share_preview_screen.dart';

class AreaReflectionsScreen extends StatelessWidget {
  const AreaReflectionsScreen({
    super.key,
    required this.area,
    required this.repository,
  });
  final LifeArea area;
  final ReflectionRepository repository;

  Future<void> _create(BuildContext context, {required bool suggested}) async {
    (String, String)? question;
    if (suggested) {
      question = await Navigator.of(context).push<(String, String)>(
        MaterialPageRoute(builder: (_) => _ReflectionSuggestions(area: area)),
      );
      if (question == null || !context.mounted) return;
    }
    if (!context.mounted) return;
    final record = await Navigator.of(context).push<Reflection>(
      MaterialPageRoute(
        builder: (_) => ReflectionEditorScreen(
          area: area,
          repository: repository,
          questionId: question?.$1,
          suggestedTitle: question?.$2,
        ),
      ),
    );
    if (record != null && context.mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              ReflectionDetailScreen(id: record.id, repository: repository),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) {
      final strings = context.strings;
      final records = repository.getForArea(area);
      return _ReflectionPage(
        actions: [
          ElevatedButton.icon(
            key: const ValueKey('reflection-new'),
            icon: const Icon(Icons.add),
            label: AppButtonLabel(strings.reflectionNew),
            onPressed: () async {
              final suggested = await showAppSheet<bool>(
                context: context,
                builder: (sheetContext) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSheetTitle(strings.reflectionNew),
                      const SizedBox(height: 20),
                      AppSheetAction(
                        icon: Icons.edit_outlined,
                        label: strings.reflectionFree,
                        onPressed: () => Navigator.pop(sheetContext, false),
                      ),
                      AppSheetAction(
                        icon: Icons.lightbulb_outline,
                        label: strings.reflectionSuggested,
                        onPressed: () => Navigator.pop(sheetContext, true),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.muted,
                        ),
                        child: AppButtonLabel(
                          strings.cancel,
                          color: context.colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (suggested != null && context.mounted) {
                await _create(context, suggested: suggested);
              }
            },
          ),
        ],
        children: [
          AreaSectionHeader(
            title: area.displayName(strings),
            icon: kAreaReflectionsIcon,
            description: strings.areaReflectionsTitle,
          ),
          const SizedBox(height: 24),
          Text(
            strings.reflectionCount(records.length),
            style: TextStyle(color: context.colors.muted),
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                strings.reflectionEmpty,
                style: TextStyle(color: context.colors.muted, height: 1.6),
              ),
            ),
          for (final record in records)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  record.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(record.createdAt.toLocal()),
                      ),
                    ],
                  ),
                ),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ReflectionDetailScreen(
                      id: record.id,
                      repository: repository,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _ReflectionSuggestions extends StatelessWidget {
  const _ReflectionSuggestions({required this.area});
  final LifeArea area;
  @override
  Widget build(BuildContext context) {
    var offset = 0;
    final groups = <Widget>[];
    for (final group in area.reflectionGroups(context.strings)) {
      final start = offset;
      offset += group.questions.length;
      groups.add(
        ExpansionTile(
          title: Text(group.title),
          children: [
            for (var i = 0; i < group.questions.length; i++)
              ListTile(
                title: Text(group.questions[i]),
                onTap: () => Navigator.pop(context, (
                  '${start + i}',
                  group.questions[i],
                )),
              ),
          ],
        ),
      );
    }
    return _ReflectionPage(
      children: [
        AreaSectionHeader(
          title: context.strings.reflectionSuggested,
          icon: kAreaReflectionsIcon,
          description: area.displayName(context.strings),
        ),
        const SizedBox(height: 24),
        ...groups,
      ],
    );
  }
}

class ReflectionEditorScreen extends StatefulWidget {
  const ReflectionEditorScreen({
    super.key,
    required this.area,
    required this.repository,
    this.existing,
    this.questionId,
    this.suggestedTitle,
  });
  final LifeArea area;
  final ReflectionRepository repository;
  final Reflection? existing;
  final String? questionId;
  final String? suggestedTitle;
  @override
  State<ReflectionEditorScreen> createState() => _ReflectionEditorScreenState();
}

class _ReflectionEditorScreenState extends State<ReflectionEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.existing?.title ?? widget.suggestedTitle ?? '',
  );
  late final _body = TextEditingController(text: widget.existing?.body ?? '');
  bool _busy = false;
  bool _canLeave = false;
  bool _asking = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _close([Reflection? record]) {
    setState(() => _canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, record);
    });
  }

  Future<void> _leave() async {
    if (_busy || _asking) return;
    final changed =
        _title.text !=
            (widget.existing?.title ?? widget.suggestedTitle ?? '') ||
        _body.text != (widget.existing?.body ?? '');
    if (changed) {
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

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final existing = widget.existing;
      final record = existing == null
          ? await widget.repository.add(
              area: widget.area,
              title: _title.text,
              body: _body.text,
              origin: widget.questionId == null
                  ? ReflectionOrigin.free
                  : ReflectionOrigin.suggested,
              questionId: widget.questionId,
            )
          : await widget.repository.update(
              existing.id,
              title: _title.text,
              body: _body.text,
            );
      if (mounted) _close(record);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.reflectionSaveError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: _ReflectionPage(
        onBack: _leave,
        actions: [
          TextButton(
            onPressed: _busy ? null : _leave,
            style: TextButton.styleFrom(foregroundColor: context.colors.muted),
            child: AppButtonLabel(strings.cancel, color: context.colors.muted),
          ),
          ElevatedButton(
            key: const ValueKey('reflection-save'),
            onPressed: _busy ? null : _save,
            child: AppButtonLabel(strings.saveChanges),
          ),
        ],
        children: [
          AreaSectionHeader(
            title: widget.existing == null
                ? strings.reflectionNew
                : strings.starQuickLookEditAction,
            icon: kAreaReflectionsIcon,
            description: widget.area.displayName(strings),
          ),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  key: const ValueKey('reflection-title'),
                  controller: _title,
                  enabled: !_busy,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: strings.reflectionTitleLabel,
                  ),
                  validator: (text) => text == null || text.trim().isEmpty
                      ? strings.reflectionRequired
                      : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('reflection-body'),
                  controller: _body,
                  enabled: !_busy,
                  minLines: 10,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: strings.reflectionBodyLabel,
                    alignLabelWithHint: true,
                  ),
                  validator: (text) => text == null || text.trim().isEmpty
                      ? strings.reflectionRequired
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReflectionDetailScreen extends StatefulWidget {
  const ReflectionDetailScreen({
    super.key,
    required this.id,
    required this.repository,
  });
  final String id;
  final ReflectionRepository repository;
  @override
  State<ReflectionDetailScreen> createState() => _ReflectionDetailScreenState();
}

class _ReflectionDetailScreenState extends State<ReflectionDetailScreen> {
  bool _deleting = false;
  Future<void> _delete() async {
    if (_deleting) return;
    final strings = context.strings;
    final confirmed = await showAppConfirmation(
      context: context,
      title: strings.reflectionDeleteTitle,
      body: strings.reflectionDeleteBody,
      cancelLabel: strings.cancel,
      confirmLabel: strings.deleteStarAction,
      tone: AppConfirmationTone.destructive,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.repository.delete(widget.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.reflectionSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final record = widget.repository.find(widget.id);
      final strings = context.strings;
      if (record == null) return const _ReflectionPage(children: []);
      return _ReflectionPage(
        actions: [
          IconButton(
            tooltip: strings.shareNowAction,
            icon: const Icon(Icons.share_outlined),
            onPressed: _deleting
                ? null
                : () => showSharePreview(
                    context: context,
                    content: ShareableReflectionCard(reflection: record),
                    shareText:
                        '${record.title} — ${record.area.displayName(strings)}',
                    fileName: 'reflection_${record.id}.png',
                  ),
          ),
          IconButton(
            tooltip: strings.starQuickLookEditAction,
            icon: const Icon(Icons.edit_outlined),
            onPressed: _deleting
                ? null
                : () => Navigator.of(context).push<Reflection>(
                    MaterialPageRoute(
                      builder: (_) => ReflectionEditorScreen(
                        area: record.area,
                        repository: widget.repository,
                        existing: record,
                      ),
                    ),
                  ),
          ),
          IconButton(
            tooltip: strings.deleteStarAction,
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleting ? null : _delete,
          ),
        ],
        children: [
          AreaSectionHeader(
            title: record.area.displayName(strings),
            icon: kAreaReflectionsIcon,
            description: strings.areaReflectionsTitle,
          ),
          const SizedBox(height: 24),
          SelectableText(
            record.title,
            style: TextStyle(
              fontFamily: kFontStarTitle,
              fontSize: 28,
              height: 1.3,
              color: context.colors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            MaterialLocalizations.of(context)
                .formatMediumDate(record.createdAt.toLocal()),
            style: TextStyle(color: context.colors.muted),
          ),
          const SizedBox(height: 28),
          SelectableText(
            record.body,
            style: TextStyle(
              fontSize: 17,
              height: 1.65,
              color: context.colors.text,
            ),
          ),
        ],
      );
    },
  );
}

/// Shared full-page framing; titles belong to the content and actions stay below.
class _ReflectionPage extends StatelessWidget {
  const _ReflectionPage({
    required this.children,
    this.actions = const [],
    this.onBack,
  });
  final List<Widget> children;
  final List<Widget> actions;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.night,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BackButton(onPressed: onBack),
                    ),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: ResponsiveContent(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: actions,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
