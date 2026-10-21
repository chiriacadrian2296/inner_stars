import 'dart:math' as math;

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
import '../widgets/app_field.dart';
import '../widgets/area_section_header.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/reader_action_bar.dart';
import '../widgets/reader_entry_content.dart' show ReaderEntrance;
import '../widgets/responsive_content.dart';
import '../widgets/shareable_reflection_card.dart';
import '../widgets/staggered_entrance.dart';
import 'share_preview_screen.dart';

class AreaReflectionsScreen extends StatefulWidget {
  const AreaReflectionsScreen({
    super.key,
    required this.area,
    required this.repository,
  });
  final LifeArea area;
  final ReflectionRepository repository;

  @override
  State<AreaReflectionsScreen> createState() => _AreaReflectionsScreenState();
}

class _AreaReflectionsScreenState extends State<AreaReflectionsScreen> {
  final _search = TextEditingController();
  LifeArea get area => widget.area;
  ReflectionRepository get repository => widget.repository;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create(BuildContext context, {required bool suggested}) async {
    (String, String)? question;
    if (suggested) {
      question = await Navigator.of(context).push<(String, String)>(
        MaterialPageRoute(
          builder: (_) =>
              _ReflectionSuggestions(area: area, repository: repository),
        ),
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
      final query = _search.text.trim().toLowerCase();
      final visible = records
          .where(
            (r) =>
                r.title.toLowerCase().contains(query) ||
                r.body.toLowerCase().contains(query),
          )
          .toList();
      return _ReflectionPage(
        actions: [
          ElevatedButton(
            key: const ValueKey('reflection-new'),
            child: AppButtonLabel(strings.reflectAction),
            onPressed: () async {
              final suggested = await showAppSheet<bool>(
                context: context,
                // Laid out like the add-photo sheet: two options, then Cancel.
                builder: (sheetContext) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSheetTitle(strings.reflectionNew),
                        const SizedBox(height: 20),
                        AppSheetAction(
                          icon: Icons.edit_outlined,
                          label: strings.reflectionFree,
                          onPressed: () => Navigator.pop(sheetContext, false),
                        ),
                        const SizedBox(height: 10),
                        AppSheetAction(
                          icon: Icons.lightbulb_outline,
                          label: strings.reflectionSuggested,
                          onPressed: () => Navigator.pop(sheetContext, true),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.muted,
                            ),
                            child: AppButtonLabel(
                              strings.cancel,
                              color: context.colors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
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
            title: strings.areaReflectionsTitle,
            icon: kAreaReflectionsIcon,
            description: area.displayName(strings),
          ),
          const SizedBox(height: 12),
          Text(
            strings.reflectionListDescription,
            style: TextStyle(color: context.colors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          if (records.isEmpty)
            _EmptyReflections(text: strings.reflectionEmpty)
          else ...[
            if (records.length >= 6 || _search.text.isNotEmpty) ...[
              AppSearchField(
                key: const ValueKey('reflection-search'),
                controller: _search,
                hintText: strings.reflectionSearchHint,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              strings.reflectionCount(visible.length),
              style: TextStyle(color: context.colors.muted),
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              _EmptyReflections(text: strings.reflectionNoResults),
            for (var i = 0; i < visible.length; i++) ...[
              if (records.length >= 6 &&
                  (i == 0 ||
                      !_sameMonth(
                        visible[i - 1].createdAt,
                        visible[i].createdAt,
                      )))
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Text(
                    MaterialLocalizations.of(context)
                        .formatMonthYear(visible[i].createdAt.toLocal()),
                    style: TextStyle(color: context.colors.muted),
                  ),
                ),
              _ReflectionCard(
                record: visible[i],
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ReflectionDetailScreen(
                      id: visible[i].id,
                      repository: repository,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      );
    },
  );
}

bool _sameMonth(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year && localA.month == localB.month;
}

/// Nothing written yet: the area's reflection glyph above a short line,
/// centred, like the app's other empty states.
class _EmptyReflections extends StatelessWidget {
  const _EmptyReflections({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(kAreaReflectionsIcon, size: 40, color: colors.muted),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// One saved reflection: title in the star-title face, date underneath,
/// the first lines of the text below, on the app's panel surface.
class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({required this.record, required this.onTap});
  final Reflection record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = MaterialLocalizations.of(context)
        .formatShortDate(record.createdAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusCard),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: panelDecoration(colors),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kFontStarTitle,
                    fontSize: 19,
                    height: 1.25,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(date, style: TextStyle(color: colors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                  record.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 14,
                    height: 1.5,
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

class _ReflectionSuggestions extends StatefulWidget {
  const _ReflectionSuggestions({required this.area, required this.repository});
  final LifeArea area;
  final ReflectionRepository repository;
  @override
  State<_ReflectionSuggestions> createState() => _ReflectionSuggestionsState();
}

class _ReflectionSuggestionsState extends State<_ReflectionSuggestions> {
  LifeArea get area => widget.area;
  ReflectionRepository get repository => widget.repository;
  int? _sample;

  void _choose(int index, String question) =>
      Navigator.pop(context, ('$index', question));

  Future<void> _related(int index, String question) async {
    final write = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _RelatedReflections(
          area: area,
          repository: repository,
          questionId: '$index',
          question: question,
        ),
      ),
    );
    if (write == true && mounted) _choose(index, question);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final questions = area.reflectionQuestions(strings);
    // Start with an unexplored question when possible.
    final answered = {
      for (final r in repository.getForArea(area))
        if (r.questionId != null) r.questionId,
    };
    final unexplored = [
      for (var i = 0; i < questions.length; i++)
        if (!answered.contains('$i')) i,
    ];
    _sample ??= unexplored.isEmpty
        ? math.Random().nextInt(questions.length)
        : unexplored[math.Random().nextInt(unexplored.length)];
    final sample = _sample!;
    var offset = 0;
    final groups = <Widget>[];
    for (final group in area.reflectionGroups(strings)) {
      final start = offset;
      offset += group.questions.length;
      groups.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          // A Material, not a decorated box, so the tiles' ink shows.
          child: Material(
            color: colors.nightPanel,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusCard),
              side: BorderSide(color: colors.nightBorder, width: kBorderWidth),
            ),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                iconColor: colors.gold,
                collapsedIconColor: colors.muted,
                title: Text(
                  group.title,
                  style: TextStyle(
                    fontFamily: kFontStarTitle,
                    fontSize: 18,
                    color: colors.text,
                  ),
                ),
                subtitle: Text(
                  strings.reflectionQuestionCount(group.questions.length),
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
                children: [
                  for (var i = 0; i < group.questions.length; i++)
                    _QuestionChoice(
                      question: group.questions[i],
                      explored: answered.contains('${start + i}'),
                      onWrite: () => _choose(start + i, group.questions[i]),
                      onRelated: () => _related(start + i, group.questions[i]),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return _ReflectionPage(
      children: [
        AreaSectionHeader(
          title: strings.reflectionSuggested,
          icon: kAreaReflectionsIcon,
          description: area.displayName(strings),
        ),
        const SizedBox(height: 24),
        Container(
          key: const ValueKey('reflection-immediate-question'),
          padding: const EdgeInsets.all(16),
          decoration: panelDecoration(colors),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuestionChoice(
                question: questions[sample],
                explored: answered.contains('$sample'),
                onWrite: () => _choose(sample, questions[sample]),
                onRelated: () => _related(sample, questions[sample]),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    key: const ValueKey('reflection-another-question'),
                    onPressed: () => setState(
                      () => _sample =
                          (sample +
                              1 +
                              math.Random().nextInt(questions.length - 1)) %
                          questions.length,
                    ),
                    child: AppButtonLabel(strings.reflectionAnotherQuestion),
                  ),
                  ElevatedButton(
                    key: const ValueKey('reflection-write-question'),
                    onPressed: () => _choose(sample, questions[sample]),
                    child: AppButtonLabel(strings.reflectionWrite),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...groups,
      ],
    );
  }
}

class _QuestionChoice extends StatelessWidget {
  const _QuestionChoice({
    required this.question,
    required this.explored,
    required this.onWrite,
    required this.onRelated,
  });
  final String question;
  final bool explored;
  final VoidCallback onWrite;
  final VoidCallback onRelated;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        borderRadius: BorderRadius.circular(kRadiusField),
        onTap: onWrite,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Text(
            question,
            style: TextStyle(
              color: context.colors.text,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ),
      if (explored)
        TextButton(
          onPressed: onRelated,
          child: AppButtonLabel(context.strings.reflectionExplored),
        ),
    ],
  );
}

class _RelatedReflections extends StatelessWidget {
  const _RelatedReflections({
    required this.area,
    required this.repository,
    required this.questionId,
    required this.question,
  });
  final LifeArea area;
  final ReflectionRepository repository;
  final String questionId;
  final String question;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) => _ReflectionPage(
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: AppButtonLabel(context.strings.reflectionWrite),
        ),
      ],
      children: [
        AreaSectionHeader(
          title: context.strings.reflectionRelated,
          icon: kAreaReflectionsIcon,
          description: area.displayName(context.strings),
        ),
        const SizedBox(height: 20),
        _QuestionContext(question: question),
        const SizedBox(height: 20),
        for (final record
            in repository
                .getForArea(area)
                .where((r) => r.questionId == questionId))
          _ReflectionCard(
            record: record,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ReflectionDetailScreen(
                  id: record.id,
                  repository: repository,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

String? _originalQuestion(
  BuildContext context,
  LifeArea area,
  String? id,
  String? snapshot,
) {
  if (snapshot != null && snapshot.isNotEmpty) return snapshot;
  final index = int.tryParse(id ?? '');
  final questions = area.reflectionQuestions(context.strings);
  return index != null && index >= 0 && index < questions.length
      ? questions[index]
      : null;
}

class _QuestionContext extends StatelessWidget {
  const _QuestionContext({required this.question});
  final String question;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: panelDecoration(context.colors),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(context.strings.reflectionQuestionLabel),
        const SizedBox(height: 8),
        SelectableText(
          question,
          style: TextStyle(
            color: context.colors.text,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
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

class _ReflectionEditorScreenState extends State<ReflectionEditorScreen>
    with WidgetsBindingObserver {
  double _keyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // Closing the keyboard (back gesture) leaves the field focused; let go of
  // the focus then, as the star form's fields do.
  @override
  void didChangeMetrics() {
    final inset = View.of(context).viewInsets.bottom;
    if (_keyboardInset > 0 && inset == 0) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _keyboardInset = inset;
  }

  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _body = TextEditingController(text: widget.existing?.body ?? '');
  bool _busy = false;
  bool _canLeave = false;
  bool _asking = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        _title.text != (widget.existing?.title ?? '') ||
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
    if (_busy || !_canSave) return;
    setState(() => _busy = true);
    try {
      final existing = widget.existing;
      final title = _title.text.trim().isNotEmpty
          ? _title.text.trim()
          : _body.text.trim().split('\n').first.characters.take(80).toString();
      final record = existing == null
          ? await widget.repository.add(
              area: widget.area,
              title: title,
              body: _body.text,
              origin: widget.questionId == null
                  ? ReflectionOrigin.free
                  : ReflectionOrigin.suggested,
              questionId: widget.questionId,
              questionText: _originalQuestion(
                context,
                widget.area,
                widget.questionId,
                widget.suggestedTitle,
              ),
            )
          : await widget.repository.update(
              existing.id,
              title: title,
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

  bool get _canSave => _body.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final writing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final question = _originalQuestion(
      context,
      widget.area,
      widget.existing?.questionId ?? widget.questionId,
      widget.existing?.questionText ?? widget.suggestedTitle,
    );
    return PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: _ReflectionPage(
        compact: writing,
        actions: [
          // A title is optional; only the reflection itself is required.
          ListenableBuilder(
            listenable: Listenable.merge([_title, _body]),
            builder: (context, _) => SaveActionButton(
              key: const ValueKey('reflection-save'),
              label: strings.saveChanges,
              lit: _canSave && !_busy,
              onPressed: _save,
            ),
          ),
        ],
        // The text runs down to the bottom of the page.
        fillLast: AppTextField(
          key: const ValueKey('reflection-body'),
          controller: _body,
          enabled: !_busy,
          expands: true,
          maxLength: kReflectionBodyMax,
          showCounter: false,
          fontSize: 17,
          lineHeight: 1.6,
        ),
        children: [
          if (!writing) ...[
            AreaSectionHeader(
              title: widget.existing == null
                  ? strings.reflectionNew
                  : strings.starQuickLookEditAction,
              icon: kAreaReflectionsIcon,
              description: widget.area.displayName(strings),
            ),
            const SizedBox(height: 16),
            if (question != null) ...[
              _QuestionContext(question: question),
              const SizedBox(height: 16),
            ],
          ],
          AppFieldLabel(
            strings.reflectionTitleLabel,
            requirement: FieldRequirement.optional,
            onReset: () => _title.clear(),
            counterController: _title,
            counterMax: kReflectionTitleMax,
          ),
          const SizedBox(height: kFieldLabelGap),
          AppTextField(
            key: const ValueKey('reflection-title'),
            controller: _title,
            hintText: strings.optionalFieldLegend,
            enabled: !_busy,
            minLines: 1,
            maxLines: 2,
            maxLength: kReflectionTitleMax,
            showCounter: false,
            fontSize: 18,
            lineHeight: 1.3,
          ),
          const SizedBox(height: 12),
          AppFieldLabel(
            strings.reflectionBodyLabel,
            requirement: FieldRequirement.required,
            onReset: () => _body.clear(),
            counterController: _body,
            counterMax: kReflectionBodyMax,
          ),
          const SizedBox(height: kFieldLabelGap),
        ],
      ),
    );
  }
}

/// Keep room for titles saved by earlier versions, which used the prompt itself.
const int kReflectionTitleMax = 200;
const int kReflectionBodyMax = 5000;

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
      final question = _originalQuestion(
        context,
        record.area,
        record.questionId,
        record.questionText,
      );
      return _ReflectionPage(
        actions: [
          // Icon-only, grouped as in "Vedi": share, then edit and delete
          // together.
          ReaderActionBar(
            entrance: const ReaderEntrance(
              animate: false,
              axis: Axis.vertical,
              reverse: false,
              lead: 0,
            ),
            actions: [
              ReaderAction(
                icon: Icons.share_outlined,
                label: strings.shareNowAction,
                group: 1,
                onTap: _deleting
                    ? null
                    : () => showSharePreview(
                        context: context,
                        content: ShareableReflectionCard(reflection: record),
                        fileName: 'reflection_${record.id}.png',
                      ),
              ),
              ReaderAction(
                icon: Icons.edit_outlined,
                label: strings.starQuickLookEditAction,
                group: 2,
                onTap: _deleting
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
              ReaderAction(
                icon: Icons.delete_outline,
                label: strings.deleteStarAction,
                group: 2,
                onTap: _deleting ? null : _delete,
              ),
            ],
          ),
        ],
        children: [
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
            '${record.area.displayName(strings)} · ${MaterialLocalizations.of(context).formatMediumDate(record.createdAt.toLocal())}',
            style: TextStyle(color: context.colors.muted),
          ),
          const SizedBox(height: 28),
          if (question != null && question != record.title) ...[
            _QuestionContext(question: question),
            const SizedBox(height: 24),
          ],
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
    this.fillLast,
    this.compact = false,
  });
  final List<Widget> children;
  final List<Widget> actions;
  final bool compact;

  /// A last block that takes whatever height the page has left below
  /// [children] (never less than [_kFillMinHeight] for the whole page, so it
  /// scrolls instead of squeezing when the keyboard is open).
  final Widget? fillLast;
  static const double _kFillMinHeight = 560;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.night,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final column = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < children.length; i++)
                      if (fillLast == null)
                        StaggeredEntrance(
                          index: math.min(i, 5),
                          child: children[i],
                        )
                      else
                        children[i],
                    if (fillLast case final last?) Expanded(child: last),
                  ],
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ResponsiveContent(
                    child: fillLast == null
                        ? column
                        : SizedBox(
                            height: math.max(
                              viewport.maxHeight - 40,
                              (compact ? 300 : _kFillMinHeight) *
                                  MediaQuery.textScalerOf(context).scale(1),
                            ),
                            child: column,
                          ),
                  ),
                );
              },
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
