import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/area_vision_repository.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_repository.dart';
import '../data/moodboard_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/reflection.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_motion.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../utils/markdown_editing.dart';
import '../utils/area_section_icons.dart';
import '../widgets/app_field.dart';
import '../widgets/area_section_header.dart';
import '../widgets/live_markdown_controller.dart';
import '../widgets/logo_watermark.dart';
import '../widgets/responsive_content.dart';
import '../widgets/shareable_reflection_card.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/vision_markdown.dart';
import 'create_flow.dart';
import 'moodboard_screen.dart';
import 'share_preview_screen.dart';
import 'vision_editor_screen.dart';

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
      final nextStep = await _chooseNextStep(context);
      if (!context.mounted || nextStep == null) return;
      await _openNextStep(context, nextStep);
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              ReflectionDetailScreen(id: record.id, repository: repository),
        ),
      );
    }
  }

  Future<_ReflectionNextStep?> _chooseNextStep(BuildContext context) {
    return _chooseReflectionNextStep(context);
  }

  Future<void> _openNextStep(
    BuildContext context,
    _ReflectionNextStep? nextStep,
  ) => _openReflectionNextStep(context, area, nextStep);

  Future<void> _showNewReflectionChoices(BuildContext context) async {
    final strings = context.strings;
    final suggested = await showAppSheet<bool>(
      context: context,
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
                key: const ValueKey('reflection-new-free'),
                icon: Icons.edit_outlined,
                label: strings.reflectionFree,
                onPressed: () => Navigator.pop(sheetContext, false),
              ),
              const SizedBox(height: 10),
              AppSheetAction(
                key: const ValueKey('reflection-new-suggested'),
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
  }

  Future<void> _openReflection(Reflection reflection) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              ReflectionDetailScreen(id: reflection.id, repository: repository),
        ),
      );

  List<Widget> _timeline(BuildContext context, List<Reflection> records) {
    final firstIndex = _search.text.isEmpty ? 1 : 0;
    final children = <Widget>[];
    for (var i = firstIndex; i < records.length; i++) {
      final startsGroup =
          i == firstIndex ||
          !_sameMonth(records[i - 1].createdAt, records[i].createdAt);
      final endsGroup =
          i == records.length - 1 ||
          !_sameMonth(records[i].createdAt, records[i + 1].createdAt);
      if (startsGroup) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              MaterialLocalizations.of(context)
                  .formatMonthYear(records[i].createdAt.toLocal()),
              style: TextStyle(color: context.colors.muted),
            ),
          ),
        );
      }
      children.add(
        _ReflectionTimelineCard(
          record: records[i],
          isFirstInGroup: startsGroup,
          isLastInGroup: endsGroup,
          onTap: () => _openReflection(records[i]),
        ),
      );
    }
    return children;
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
            onPressed: () => _showNewReflectionChoices(context),
          ),
        ],
        centeredChild: records.isEmpty
            ? Text(
                strings.reflectionEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.muted, height: 1.6),
              )
            : null,
        children: [
          AreaSectionHeader(
            title: area.displayName(strings),
            icon: kAreaReflectionsIcon,
            description: strings.reflectionListDescription,
          ),
          const SizedBox(height: 24),
          if (records.isNotEmpty) ...[
            if (records.length >= 6 || _search.text.isNotEmpty) ...[
              AppSearchField(
                key: const ValueKey('reflection-search'),
                controller: _search,
                hintText: strings.reflectionSearchHint,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],
            if (_search.text.isNotEmpty) ...[
              Text(
                strings.reflectionCount(visible.length),
                style: TextStyle(color: context.colors.muted),
              ),
              const SizedBox(height: 16),
            ],
            if (visible.isEmpty)
              _EmptyReflections(text: strings.reflectionNoResults),
            if (visible.isNotEmpty && _search.text.isEmpty) ...[
              AppFieldLabel(strings.reflectionLatestLabel),
              const SizedBox(height: 10),
              _ReflectionCard(
                record: visible.first,
                featured: true,
                onTap: () => _openReflection(visible.first),
              ),
              if (visible.length > 1) ...[
                const SizedBox(height: 16),
                AppFieldLabel(strings.reflectionEarlierLabel),
                const SizedBox(height: 12),
              ],
            ],
            ..._timeline(context, visible),
          ],
        ],
      );
    },
  );
}

enum _ReflectionNextStep { star, vision, moodboard }

Future<_ReflectionNextStep?> _chooseReflectionNextStep(BuildContext context) {
  final strings = context.strings;
  return showAppSheet<_ReflectionNextStep>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSheetTitle(strings.reflectionNextStepTitle),
              const SizedBox(height: 10),
              Text(
                strings.reflectionNextStepBody,
                style: TextStyle(color: sheetContext.colors.muted, height: 1.5),
              ),
              const SizedBox(height: 20),
              AppSheetAction(
                key: const ValueKey('reflection-next-star'),
                icon: Icons.auto_awesome_outlined,
                label: strings.reflectionCreateStarAction,
                onPressed: () =>
                    Navigator.pop(sheetContext, _ReflectionNextStep.star),
              ),
              const SizedBox(height: 10),
              AppSheetAction(
                key: const ValueKey('reflection-next-vision'),
                icon: kAreaVisionIcon,
                label: strings.reflectionUpdateVisionAction,
                onPressed: () =>
                    Navigator.pop(sheetContext, _ReflectionNextStep.vision),
              ),
              const SizedBox(height: 10),
              AppSheetAction(
                key: const ValueKey('reflection-next-moodboard'),
                icon: kAreaMoodboardIcon,
                label: strings.reflectionAddMoodboardAction,
                onPressed: () =>
                    Navigator.pop(sheetContext, _ReflectionNextStep.moodboard),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  key: const ValueKey('reflection-next-not-now'),
                  onPressed: () => Navigator.pop(sheetContext),
                  style: TextButton.styleFrom(
                    foregroundColor: sheetContext.colors.muted,
                  ),
                  child: AppButtonLabel(
                    strings.reflectionNotNowAction,
                    color: sheetContext.colors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _openReflectionNextStep(
  BuildContext context,
  LifeArea area,
  _ReflectionNextStep? nextStep,
) async {
  switch (nextStep) {
    case _ReflectionNextStep.star:
      final projectRepository = await ProjectRepository.create();
      final starsShapeRepository = await StarsShapeRepository.create();
      final starRepository = await StarRepository.create();
      final habitRepository = await HabitRepository.create();
      if (!context.mounted) return;
      await showCreatePage(
        context,
        projectRepository: projectRepository,
        starsShapeRepository: starsShapeRepository,
        starRepository: starRepository,
        habitRepository: habitRepository,
        startWithoutSelection: true,
        area: area,
      );
      return;
    case _ReflectionNextStep.vision:
      final visionRepository = await AreaVisionRepository.create();
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              VisionEditorScreen(area: area, repository: visionRepository),
        ),
      );
      return;
    case _ReflectionNextStep.moodboard:
      final moodboardRepository = await MoodboardRepository.create();
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              MoodboardScreen(area: area, repository: moodboardRepository),
        ),
      );
      return;
    case null:
      return;
  }
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

/// One saved reflection: a quiet gold marker and date establish the rhythm,
/// while the title and first lines carry the content. Suggested reflections
/// also keep their starting-question context visible without repeating the
/// whole prompt and overwhelming the user's own words.
class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({
    required this.record,
    required this.onTap,
    this.featured = false,
  });
  final Reflection record;
  final VoidCallback onTap;
  final bool featured;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = MaterialLocalizations.of(context)
        .formatShortDate(record.createdAt.toLocal());
    final suggested = record.origin == ReflectionOrigin.suggested;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusCard),
          child: Ink(
            padding: EdgeInsets.fromLTRB(
              featured ? 20 : 16,
              featured ? 20 : 16,
              featured ? 16 : 12,
              featured ? 20 : 16,
            ),
            decoration: panelDecoration(colors),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.gold.withValues(alpha: 0.1),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.45),
                      width: kBorderWidth,
                    ),
                  ),
                  child: Icon(
                    kAreaReflectionsIcon,
                    size: 20,
                    color: colors.gold,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            date,
                            style: TextStyle(
                              color: colors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                          _ReflectionOriginBadge(suggested: suggested),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        record.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kFontStarTitle,
                          fontSize: featured ? 24 : 20,
                          height: 1.25,
                          color: colors.text,
                        ),
                      ),
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
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.muted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReflectionTimelineCard extends StatelessWidget {
  const _ReflectionTimelineCard({
    required this.record,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.onTap,
  });

  final Reflection record;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 32),
        child: _ReflectionCard(record: record, onTap: onTap),
      ),
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: 24,
        child: CustomPaint(
          painter: _ReflectionTimelinePainter(
            lineColor: context.colors.nightBorder,
            markerColor: context.colors.gold,
            isFirstInGroup: isFirstInGroup,
            isLastInGroup: isLastInGroup,
          ),
        ),
      ),
    ],
  );
}

class _ReflectionTimelinePainter extends CustomPainter {
  const _ReflectionTimelinePainter({
    required this.lineColor,
    required this.markerColor,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  final Color lineColor;
  final Color markerColor;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  @override
  void paint(Canvas canvas, Size size) {
    const markerRadius = 4.0;
    const cardBottomSpacing = 12.0;
    final markerCenter = ((size.height - cardBottomSpacing) / 2)
        .clamp(markerRadius, size.height - markerRadius)
        .toDouble();
    final center = Offset(size.width / 2, markerCenter);
    if (!(isFirstInGroup && isLastInGroup)) {
      canvas.drawLine(
        Offset(center.dx, isFirstInGroup ? markerCenter : 0),
        Offset(center.dx, isLastInGroup ? markerCenter : size.height),
        Paint()
          ..color = lineColor
          ..strokeWidth = kBorderWidth,
      );
    }
    canvas.drawCircle(
      center,
      markerRadius * 2,
      Paint()..color = markerColor.withValues(alpha: 0.18),
    );
    canvas.drawCircle(center, markerRadius, Paint()..color = markerColor);
  }

  @override
  bool shouldRepaint(covariant _ReflectionTimelinePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.markerColor != markerColor ||
      oldDelegate.isFirstInGroup != isFirstInGroup ||
      oldDelegate.isLastInGroup != isLastInGroup;
}

class _ReflectionOriginBadge extends StatelessWidget {
  const _ReflectionOriginBadge({required this.suggested});

  final bool suggested;

  @override
  Widget build(BuildContext context) => _ReflectionTag(
    label: suggested
        ? context.strings.reflectionSuggestedBadge
        : context.strings.reflectionFreeBadge,
  );
}

class _ReflectionTag extends StatelessWidget {
  const _ReflectionTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.colors.gold.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: context.colors.gold.withValues(alpha: 0.32),
        width: kBorderWidth,
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: context.colors.gold,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.45,
      ),
    ),
  );
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
  int? _selected;
  int? _expandedGroup = 0;

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
    final active = _selected ?? sample;
    var offset = 0;
    final groups = <Widget>[];
    final reflectionGroups = area.reflectionGroups(strings);
    for (
      var groupIndex = 0;
      groupIndex < reflectionGroups.length;
      groupIndex++
    ) {
      final group = reflectionGroups[groupIndex];
      final start = offset;
      offset += group.questions.length;
      groups.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: colors.nightPanel,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusCard),
              side: BorderSide(color: colors.nightBorder, width: kBorderWidth),
            ),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: colors.nightBorder),
              child: ExpansionTile(
                key: ValueKey(
                  'reflection-group-$groupIndex-${_expandedGroup == groupIndex}',
                ),
                initiallyExpanded: _expandedGroup == groupIndex,
                onExpansionChanged: (expanded) => setState(
                  () => _expandedGroup = expanded ? groupIndex : null,
                ),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                shape: const Border(),
                collapsedShape: const Border(),
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
                  for (var i = 0; i < group.questions.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: colors.nightBorder),
                    _QuestionChoice(
                      question: group.questions[i],
                      selected: active == start + i,
                      answerCount: repository
                          .getForArea(area)
                          .where((r) => r.questionId == '${start + i}')
                          .length,
                      onSelect: () => setState(() => _selected = start + i),
                      onRelated: () => _related(start + i, group.questions[i]),
                    ),
                  ],
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
          title: area.displayName(strings),
          icon: kAreaReflectionsIcon,
          description: strings.reflectionSuggestionsDescription,
        ),
        const SizedBox(height: 24),
        Container(
          key: const ValueKey('reflection-immediate-question'),
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: panelDecoration(colors),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppFieldLabel(strings.reflectionQuestionOfMomentLabel),
              const SizedBox(height: 8),
              Visibility(
                visible: answered.contains('$active'),
                maintainSize: true,
                maintainState: true,
                maintainAnimation: true,
                child: _ReflectionTag(label: strings.reflectionExplored),
              ),
              const SizedBox(height: 12),
              _MomentQuestion(
                question: questions[active],
                questions: questions,
              ),
              const SizedBox(height: 18),
              Center(
                child: SizedBox(
                  width: 280,
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('reflection-previous-question'),
                        tooltip: strings.reflectionPreviousQuestion,
                        onPressed: () => setState(() {
                          _selected = (active - 1) % questions.length;
                        }),
                        icon: Icon(Icons.chevron_left, color: colors.text),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (answered.contains('$active')) ...[
                              Flexible(
                                child: TextButton(
                                  key: const ValueKey(
                                    'reflection-read-question',
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _related(active, questions[active]),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: AppButtonLabel(
                                      strings.reflectionReadAction,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                key: const ValueKey(
                                  'reflection-write-question',
                                ),
                                onPressed: () =>
                                    _choose(active, questions[active]),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: AppButtonLabel(
                                    strings.reflectionWrite,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('reflection-next-question'),
                        tooltip: strings.reflectionNextQuestion,
                        onPressed: () => setState(() {
                          _selected = (active + 1) % questions.length;
                        }),
                        icon: Icon(Icons.chevron_right, color: colors.text),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        ...groups,
      ],
    );
  }
}

/// Reserve the same space for every prompt so navigation never moves.
class _MomentQuestion extends StatelessWidget {
  const _MomentQuestion({required this.question, required this.questions});

  final String question;
  final List<String> questions;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontFamily: kFontStarTitle,
        color: context.colors.text,
        fontSize: 24,
        height: 1.35,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        double measure(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final height = painter.height;
          painter.dispose();
          return height;
        }

        final height = questions.fold<double>(
          measure('Ag\nAg'),
          (height, text) => math.max(height, measure(text)),
        );
        return SizedBox(
          height: height,
          child: Center(
            child: Text(question, textAlign: TextAlign.center, style: style),
          ),
        );
      },
    );
  }
}

class _QuestionChoice extends StatelessWidget {
  const _QuestionChoice({
    required this.question,
    required this.selected,
    required this.answerCount,
    required this.onSelect,
    required this.onRelated,
  });
  final String question;
  final bool selected;
  final int answerCount;
  final VoidCallback onSelect;
  final VoidCallback onRelated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusField),
        onTap: onSelect,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? colors.gold.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadiusField),
            border: Border.all(
              color: selected ? colors.gold : Colors.transparent,
              width: kBorderWidth,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question,
                      style: TextStyle(
                        color: colors.text,
                        fontFamily: kFontStarTitle,
                        fontSize: 18,
                        height: 1.45,
                      ),
                    ),
                    if (answerCount > 0) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onRelated,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.strings.reflectionExplored,
                              style: TextStyle(
                                color: colors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              ' · $answerCount',
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.check_circle_outline_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? colors.gold : colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          title: area.displayName(context.strings),
          icon: kAreaReflectionsIcon,
          description: context.strings.reflectionRelatedDescription,
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
    padding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: context.colors.gold.withValues(alpha: 0.7),
          width: 2,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReflectionTag(label: context.strings.reflectionQuestionLabel),
        const SizedBox(height: 8),
        SelectableText(
          question,
          style: TextStyle(
            color: context.colors.text,
            fontFamily: kFontStarTitle,
            fontSize: 18,
            fontStyle: FontStyle.italic,
            height: 1.45,
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
    _focus.addListener(_syncFocus);
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

  late final _initialTitle =
      widget.existing?.title ?? widget.suggestedTitle ?? '';
  late final _title = TextEditingController(text: _initialTitle);
  late final _body = LiveMarkdownController(text: widget.existing?.body ?? '');
  final _focus = FocusNode();
  final _undo = UndoHistoryController();
  bool _busy = false;
  bool _canLeave = false;
  bool _asking = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_syncFocus);
    _title.dispose();
    _body.dispose();
    _focus.dispose();
    _undo.dispose();
    super.dispose();
  }

  void _syncFocus() {
    _body.focused = _focus.hasFocus;
    if (mounted) setState(() {});
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
        _title.text != _initialTitle ||
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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      final existing = widget.existing;
      final title = _title.text.trim();
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

  Future<void> _share() {
    final now = DateTime.now();
    final reflection =
        widget.existing ??
        Reflection(
          id: 'preview',
          area: widget.area,
          title: _title.text.trim(),
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
          createdAt: now,
          updatedAt: now,
        );
    return showSharePreview(
      context: context,
      content: ShareableReflectionCard(
        reflection: reflection.edit(
          title: _title.text.trim(),
          body: _body.text,
        ),
      ),
      fileName: 'reflection_${reflection.id}.png',
    );
  }

  void _format(
    String marker, {
    bool block = false,
    bool numbered = false,
    bool toggle = false,
    String? closing,
  }) {
    _body.value = formatMarkdown(
      _body.value,
      marker,
      block: block,
      numbered: numbered,
      toggle: toggle,
      closing: closing,
    );
    _focus.requestFocus();
  }

  void _insertDivider() {
    _body.value = insertMarkdownDivider(_body.value);
    _focus.requestFocus();
  }

  bool get _canSave =>
      _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final strings = context.strings;
    final colors = context.colors;
    final suggested =
        widget.questionId != null ||
        widget.existing?.origin == ReflectionOrigin.suggested;
    Widget tool(IconData icon, String label, VoidCallback action) => IconButton(
      tooltip: label,
      style: IconButton.styleFrom(
        foregroundColor: colors.text,
        disabledForegroundColor: colors.muted,
      ),
      icon: Icon(icon),
      onPressed: _busy ? null : action,
    );
    return PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: colors.night,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedOpacity(
                  duration: kMotionFast,
                  opacity: _focus.hasFocus ? 0.68 : 1,
                  child: StaggeredEntrance(
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
                        icon: kAreaReflectionsIcon,
                        description: widget.existing == null
                            ? strings.reflectionWriteDescription
                            : strings.reflectionEditDescription,
                        descriptionChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!keyboardVisible)
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  AppFieldLabel(strings.reflectionTitleLabel),
                                  _ReflectionOriginBadge(suggested: suggested),
                                ],
                              ),
                            if (!keyboardVisible) const SizedBox(height: 6),
                            TextField(
                              key: const ValueKey('reflection-title'),
                              controller: _title,
                              enabled: !_busy,
                              minLines: 1,
                              maxLines: keyboardVisible ? 1 : 3,
                              maxLength: kReflectionTitleMax,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _focus.requestFocus(),
                              style: TextStyle(
                                color: colors.text,
                                fontFamily: kFontStarTitle,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                counterText: '',
                                hintText: strings.reflectionTitleLabel,
                                hintStyle: TextStyle(
                                  color: colors.muted,
                                  fontFamily: kFontStarTitle,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StaggeredEntrance(
                            index: 1,
                            axis: Axis.horizontal,
                            child: PopupMenuButton<int>(
                              tooltip: strings.visionHeading,
                              enabled: !_busy,
                              color: colors.nightPanel,
                              surfaceTintColor: Colors.transparent,
                              onSelected: (level) => _format(
                                '${'#' * level} ',
                                block: true,
                                toggle: true,
                              ),
                              itemBuilder: (context) => [
                                for (var level = 1; level <= 3; level++)
                                  PopupMenuItem(
                                    value: level,
                                    child: Center(
                                      child: Text(
                                        '${strings.visionHeading} $level',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: colors.text),
                                      ),
                                    ),
                                  ),
                              ],
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: Text(
                                    'H',
                                    style: TextStyle(
                                      color: colors.text,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _toolbarDivider(colors),
                          tool(
                            Icons.format_bold,
                            strings.visionBold,
                            () => _format('**', toggle: true),
                          ),
                          tool(
                            Icons.format_italic,
                            strings.visionItalic,
                            () => _format('*', toggle: true),
                          ),
                          tool(
                            Icons.format_underlined,
                            strings.visionUnderline,
                            () => _format('<u>', closing: '</u>', toggle: true),
                          ),
                          _toolbarDivider(colors),
                          tool(
                            Icons.format_list_bulleted,
                            strings.visionBulletList,
                            () => _format('• ', block: true, toggle: true),
                          ),
                          tool(
                            Icons.format_list_numbered,
                            strings.visionNumberedList,
                            () => _format(
                              '1. ',
                              block: true,
                              numbered: true,
                              toggle: true,
                            ),
                          ),
                          _toolbarDivider(colors),
                          tool(
                            Icons.horizontal_rule,
                            strings.visionDivider,
                            _insertDivider,
                          ),
                          _toolbarDivider(colors),
                          ValueListenableBuilder<UndoHistoryValue>(
                            valueListenable: _undo,
                            builder: (context, value, _) => Row(
                              children: [
                                IconButton(
                                  tooltip: strings.visionUndo,
                                  style: IconButton.styleFrom(
                                    foregroundColor: colors.text,
                                    disabledForegroundColor: colors.muted,
                                  ),
                                  icon: const Icon(Icons.undo),
                                  onPressed: value.canUndo && !_busy
                                      ? _undo.undo
                                      : null,
                                ),
                                IconButton(
                                  tooltip: strings.visionRedo,
                                  style: IconButton.styleFrom(
                                    foregroundColor: colors.text,
                                    disabledForegroundColor: colors.muted,
                                  ),
                                  icon: const Icon(Icons.redo),
                                  onPressed: value.canRedo && !_busy
                                      ? _undo.redo
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    height: 1,
                    thickness: 0.75,
                    color: colors.nightBorder,
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: AnimatedOpacity(
                          duration: kMotionFast,
                          opacity: _focus.hasFocus ? 0.28 : 1,
                          child: LogoWatermark(
                            scale: logoWatermarkScale(StarKind.unlit),
                            color: logoWatermarkColor(colors, StarKind.unlit),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: StaggeredEntrance(
                          index: 2,
                          child: TextField(
                            key: const ValueKey('reflection-body'),
                            controller: _body,
                            focusNode: _focus,
                            undoController: _undo,
                            readOnly: _busy,
                            expands: true,
                            minLines: null,
                            maxLines: null,
                            maxLength: kReflectionBodyMax,
                            textAlignVertical: TextAlignVertical.top,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(
                              fontFamily: kFontStarTitle,
                              color: colors.text,
                              fontSize: 21,
                              height: 1.6,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              counterText: '',
                              hintText: strings.reflectionAnswerHint,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: keyboardVisible ? 4 : 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                StaggeredEntrance(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ListenableBuilder(
                          listenable: Listenable.merge([_title, _body]),
                          builder: (context, _) => TextButton(
                            onPressed: _busy || !_canSave ? null : _share,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: keyboardVisible ? 8 : 22,
                                vertical: 14,
                              ),
                            ),
                            child: AppButtonLabel(
                              strings.starQuickLookShareAction,
                            ),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: Listenable.merge([_title, _body]),
                          builder: (context, _) => ElevatedButton(
                            style: keyboardVisible
                                ? ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  )
                                : null,
                            key: const ValueKey('reflection-save'),
                            onPressed: _busy || !_canSave ? null : _save,
                            child: AppButtonLabel(strings.saveChanges),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarDivider(AppColors colors) => SizedBox(
    height: 24,
    child: VerticalDivider(
      width: 24,
      thickness: 0.75,
      color: colors.nightBorder,
    ),
  );
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

  Future<void> _continue(LifeArea area) async {
    final nextStep = await _chooseReflectionNextStep(context);
    if (!mounted) return;
    await _openReflectionNextStep(context, area, nextStep);
  }

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
        separateLastActionOnCompact: true,
        actions: [
          ElevatedButton(
            key: const ValueKey('reflection-edit'),
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
            child: AppButtonLabel(strings.starQuickLookEditAction),
          ),
          ElevatedButton(
            key: const ValueKey('reflection-share'),
            onPressed: _deleting
                ? null
                : () => showSharePreview(
                    context: context,
                    content: ShareableReflectionCard(reflection: record),
                    fileName: 'reflection_${record.id}.png',
                  ),
            child: AppButtonLabel(strings.shareNowAction),
          ),
          ElevatedButton(
            key: const ValueKey('reflection-continue'),
            onPressed: _deleting ? null : () => _continue(record.area),
            child: AppButtonLabel(strings.reflectionContinueLabel),
          ),
          ElevatedButton(
            key: const ValueKey('reflection-delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.dangerBackground,
              foregroundColor: context.colors.danger,
            ),
            onPressed: _deleting ? null : _delete,
            child: AppButtonLabel(
              strings.deleteStarAction,
              color: context.colors.danger,
            ),
          ),
        ],
        children: [
          AreaSectionHeader(
            title: record.area.displayName(strings),
            icon: kAreaReflectionsIcon,
            description: strings.reflectionReadDescription,
            descriptionChild: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ReflectionOriginBadge(
                  suggested: record.origin == ReflectionOrigin.suggested,
                ),
                Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(record.createdAt.toLocal()),
                  style: TextStyle(color: context.colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            record.title,
            style: TextStyle(
              fontFamily: kFontStarTitle,
              fontSize: 28,
              height: 1.3,
              color: context.colors.text,
            ),
          ),
          const SizedBox(height: 28),
          if (question != null && question != record.title) ...[
            _QuestionContext(question: question),
            const SizedBox(height: 24),
          ],
          VisionMarkdown(data: record.body, color: context.colors.text),
          const SizedBox(height: 12),
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
    this.separateLastActionOnCompact = false,
    this.centeredChild,
  });
  final List<Widget> children;
  final List<Widget> actions;
  final bool separateLastActionOnCompact;
  final Widget? centeredChild;

  Widget _buildActions(BoxConstraints constraints) {
    if (separateLastActionOnCompact &&
        constraints.maxWidth < 520 &&
        actions.length > 1) {
      final primaryActions = actions.take(actions.length - 1).toList();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < primaryActions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: primaryActions[i]),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Center(child: actions.last),
        ],
      );
    }
    final wideActions = separateLastActionOnCompact && actions.length > 1
        ? [actions.last, ...actions.take(actions.length - 1)]
        : actions;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: wideActions,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.night,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: centeredChild == null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ResponsiveContent(
                      child: _ReflectionPageChildren(children: children),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: ResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ReflectionPageChildren(children: children),
                          Expanded(child: Center(child: centeredChild)),
                        ],
                      ),
                    ),
                  ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: ResponsiveContent(
                child: LayoutBuilder(
                  builder: (context, constraints) => _buildActions(constraints),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ReflectionPageChildren extends StatelessWidget {
  const _ReflectionPageChildren({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++)
        StaggeredEntrance(index: math.min(i, 5), child: children[i]),
    ],
  );
}
