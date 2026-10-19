import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';

import '../data/reader_entries.dart';
import '../l10n/strings_scope.dart';
import '../models/display_text.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';
import '../utils/entity_insights.dart';
import '../utils/date_math.dart';
import '../utils/habit_stats.dart';
import '../utils/icon_for_slug.dart';
import '../widgets/activity_check_card.dart';
import '../widgets/area_icon.dart';
import '../widgets/entity_insight_content.dart';
import '../widgets/entity_insights_scope.dart';
import '../widgets/habit_stepper_dialog.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import 'star_reader_screen.dart';

Future<void> openTodayHabits(
  BuildContext context,
  InsightEntity? entity,
) async {
  assert(entity == null || entity.aggregate);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => TodayHabitsScreen(entity: entity)),
  );
}

/// Habits focus on today; goals use the existing achievement flow.
class TodayHabitsScreen extends StatefulWidget {
  const TodayHabitsScreen({super.key, required this.entity});
  final InsightEntity? entity;
  @override
  State<TodayHabitsScreen> createState() => _TodayHabitsScreenState();
}

class _TodayHabitsScreenState extends State<TodayHabitsScreen> {
  bool _saving = false;
  bool _goals = false;
  bool _reverse = false;

  void _setGoals(bool goals) {
    if (_saving || goals == _goals) return;
    setState(() {
      _reverse = !goals;
      _goals = goals;
    });
  }

  void _swipe(double velocity) {
    if (velocity.abs() < 180) return;
    _setGoals(velocity.isNegative);
  }

  _ManagementData _data(EntityInsightsController controller) =>
      _ManagementData.read(controller, widget.entity);

  void _reportError() {
    if (!mounted) return;
    EntityInsightsScope.maybeOf(context)!.refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.insightSaveError)));
  }

  Future<void> _change(Habit habit) async {
    if (_saving) return;
    final controller = EntityInsightsScope.maybeOf(context)!;
    final data = _data(controller);
    setState(() => _saving = true);
    try {
      if (habit.frequency == HabitFrequency.daily &&
          habit.targetPerPeriod > 1) {
        await showHabitStepperDialog(
          context: context,
          habit: habit,
          repository: controller.completions,
        );
      } else if (data.todayCount(habit) > 0) {
        await controller.completions.unmarkDone(habit.id, data.today);
      } else {
        await controller.completions.markDone(habit.id, date: data.today);
      }
    } catch (_) {
      _reportError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _achieve(Star goal) async {
    if (_saving) return;
    final controller = EntityInsightsScope.maybeOf(context)!;
    setState(() => _saving = true);
    try {
      final result = await showMarkAchievedSheet(context);
      if (result == null || !mounted) return;
      if (!controller.stars.getAll().any((s) => s.id == goal.id && s.isUnlit)) {
        return;
      }
      await controller.stars.markAchieved(
        goal.id,
        intensity: result.intensity,
        achievedDate: result.achievedDate,
        photoPath: result.photoPath,
        media: result.media,
      );
    } catch (_) {
      _reportError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// A goal ticked off today stays on the list until the day ends. The star
  /// record has no "was a goal" flag, so it is recognised as a star that was
  /// created before it was achieved (or carries a target date).
  bool _achievedGoalToday(Star s, DateTime today) {
    final achieved = s.achievedDate;
    if (!s.isLit || achieved == null) return false;
    if (achieved.year != today.year ||
        achieved.month != today.month ||
        achieved.day != today.day) {
      return false;
    }
    return s.targetDate != null ||
        s.createdAt.isBefore(achieved.subtract(const Duration(minutes: 1)));
  }

  Future<void> _unachieve(Star goal) async {
    if (_saving) return;
    final controller = EntityInsightsScope.maybeOf(context)!;
    setState(() => _saving = true);
    try {
      await controller.stars.markNotAchieved(goal.id);
    } catch (_) {
      _reportError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<ReaderEntry> _entries(bool goals) {
    final data = _data(EntityInsightsScope.maybeOf(context)!);
    final entries = goals
        ? data.stars
              .where((s) => s.isUnlit || _achievedGoalToday(s, data.today))
              .map<ReaderEntry>(StarEntry.new)
              .toList()
        : data.activeHabits.map<ReaderEntry>(PulsarEntry.new).toList();
    DateTime created(ReaderEntry entry) => switch (entry) {
      StarEntry(:final star) => star.createdAt,
      PulsarEntry(:final habit) => habit.createdAt,
      _ => DateTime(0),
    };
    entries.sort((a, b) {
      final projectById = {
        for (final project in data.projects) project.id: project,
      };
      final aProject = projectById[_projectId(a)];
      final bProject = projectById[_projectId(b)];
      if (widget.entity == null) {
        final byArea = (aProject?.area.index ?? 0).compareTo(
          bProject?.area.index ?? 0,
        );
        if (byArea != 0) return byArea;
      }
      if (widget.entity?.kind != InsightEntityKind.project) {
        final byProject = (aProject?.displayName ?? '').compareTo(
          bProject?.displayName ?? '',
        );
        if (byProject != 0) return byProject;
      }
      final byDate = created(a).compareTo(created(b));
      return byDate == 0 ? a.key.compareTo(b.key) : byDate;
    });
    return entries;
  }

  String _projectId(ReaderEntry entry) => switch (entry) {
    StarEntry(:final star) => star.projectId,
    PulsarEntry(:final habit) => habit.projectId,
    _ => '',
  };

  Future<void> _view(ReaderEntry entry) async {
    final controller = EntityInsightsScope.maybeOf(context)!;
    final goals = _goals;
    final entries = _entries(goals);
    final index = entries.indexWhere((e) => e.key == entry.key);
    if (index < 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StarReaderScreen(
          repository: controller.stars,
          initialEntries: entries,
          startIndex: index,
          projectsById: {
            for (final project in controller.projects.getAll())
              project.id: project,
          },
          allowEdit: true,
          projectRepository: controller.projects,
          starsShapeRepository: controller.shapes,
          habitRepository: controller.habits,
          habitCompletionRepository: controller.completions,
          refreshEntries: () => _entries(goals),
        ),
      ),
    );
  }

  List<_ManagementGroup> _groups(
    List<ReaderEntry> entries,
    _ManagementData data,
  ) {
    final grouped = <String, List<ReaderEntry>>{};
    for (final entry in entries) {
      (grouped[_projectId(entry)] ??= []).add(entry);
    }
    return [
      for (final project in data.projects)
        if (grouped[project.id]?.isNotEmpty ?? false)
          _ManagementGroup(project, grouped[project.id]!),
    ];
  }

  Widget _entryCard(ReaderEntry entry, _ManagementData data) {
    final s = context.strings;
    return switch (entry) {
      PulsarEntry(:final habit) => ActivityCheckCard(
        icon: habit.iconSlug.isEmpty
            ? StarKind.pulsar.icon
            : iconForSlug(habit.iconSlug),
        title: habit.displayTitle,
        lit: data.doneToday(habit),
        onTap: _saving ? null : () => _view(entry),
        figures: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (habit.frequency == HabitFrequency.daily &&
                habit.targetPerPeriod > 1)
              Text(
                '${data.todayCount(habit)}/${habit.targetPerPeriod}',
                style: context.typography.supporting,
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.autorenew_rounded,
                  size: 14,
                  color: context.colors.muted,
                ),
                const SizedBox(width: 3),
                Text(
                  '${data.cycleProgress(habit).clamp(0, habit.cycleLength)}/${habit.cycleLength}',
                  style: context.typography.supporting,
                ),
              ],
            ),
          ],
        ),
        actionIcon:
            habit.frequency == HabitFrequency.daily && habit.targetPerPeriod > 1
            ? Icons.add_circle_outline
            : data.doneToday(habit)
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        actionLabel:
            habit.frequency == HabitFrequency.daily && habit.targetPerPeriod > 1
            ? s.habitProgressToday(
                data.todayCount(habit),
                habit.targetPerPeriod,
              )
            : data.doneToday(habit)
            ? s.habitUncheckAction
            : s.habitCheckAction,
        onAction: _saving ? null : () => _change(habit),
      ),
      StarEntry(:final star) => ActivityCheckCard(
        icon: star.iconSlug.isEmpty
            ? StarKind.unlit.icon
            : iconForSlug(star.iconSlug),
        title: star.displayTitle,
        lit: star.isLit,
        onTap: _saving ? null : () => _view(entry),
        actionIcon: star.isLit
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        actionLabel: star.isLit
            ? s.habitUncheckAction
            : s.completeActivityAction,
        onAction: _saving
            ? null
            : () => star.isLit ? _unachieve(star) : _achieve(star),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = EntityInsightsScope.maybeOf(context)!;
    final data = _data(controller);
    final entries = _entries(_goals);
    final groups = _groups(entries, data);
    final s = context.strings;
    return Scaffold(
      backgroundColor: context.colors.night,
      body: SafeArea(
        child: GestureDetector(
          key: const ValueKey('management-swipe-surface'),
          onHorizontalDragEnd: (details) =>
              _swipe(details.velocity.pixelsPerSecond.dx),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _goals ? s.manageGoals : s.manageHabits,
                    style: context.typography.utilityPageTitle,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: AnimatedToggleSwitch<bool>.rolling(
                        current: _goals,
                        values: const [false, true],
                        height: 40,
                        borderWidth: kBorderWidth,
                        iconOpacity: 1,
                        onChanged: _saving ? null : _setGoals,
                        iconBuilder: (value, size) => Semantics(
                          selected: value == _goals,
                          child: Tooltip(
                            message: value ? s.manageGoals : s.manageHabits,
                            child: Icon(
                              value
                                  ? StarKind.unlit.icon
                                  : StarKind.pulsar.icon,
                              size: 21,
                              color: value == _goals
                                  ? context.colors.night
                                  : context.colors.muted,
                            ),
                          ),
                        ),
                        style: ToggleStyle(
                          backgroundColor: context.colors.nightPanel,
                          indicatorColor: context.colors.gold,
                          borderColor: context.colors.nightBorder,
                          borderRadius: BorderRadius.circular(kRadiusField),
                          indicatorBorderRadius: BorderRadius.circular(
                            kRadiusField,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.entity == null
                        ? s.lightScopeAll
                        : insightTitle(
                            context,
                            controller.read(widget.entity!),
                          ),
                    style: TextStyle(fontSize: 22, color: context.colors.text),
                  ),
                  if (!_goals) ...[
                    const SizedBox(height: 8),
                    Text(
                      MaterialLocalizations.of(context)
                          .formatFullDate(data.today),
                      style: TextStyle(color: context.colors.muted),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (entries.isEmpty)
                    StaggeredEntrance(
                      index: 0,
                      axis: Axis.horizontal,
                      replayKey: _goals,
                      reverse: _reverse,
                      child: Text(
                        _goals ? s.manageGoalsEmpty : s.insightNoHabits,
                        style: TextStyle(color: context.colors.muted),
                      ),
                    ),
                  for (var i = 0; i < groups.length; i++) ...[
                    if (widget.entity == null &&
                        (i == 0 ||
                            groups[i - 1].project.area !=
                                groups[i].project.area)) ...[
                      if (i > 0) const SizedBox(height: kSpaceMd),
                      StaggeredEntrance(
                        index: i,
                        axis: Axis.horizontal,
                        replayKey: _goals,
                        reverse: _reverse,
                        child: _AreaGroupHeader(area: groups[i].project.area),
                      ),
                      const SizedBox(height: kSpaceSm),
                    ],
                    if (widget.entity?.kind != InsightEntityKind.project) ...[
                      StaggeredEntrance(
                        index: i + 1,
                        axis: Axis.horizontal,
                        replayKey: _goals,
                        reverse: _reverse,
                        child: _ProjectGroupHeader(project: groups[i].project),
                      ),
                      const SizedBox(height: kSpaceSm),
                    ],
                    for (var j = 0; j < groups[i].entries.length; j++)
                      Padding(
                        key: ValueKey(groups[i].entries[j].key),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StaggeredEntrance(
                          index: i + j + 2,
                          axis: Axis.horizontal,
                          replayKey: _goals,
                          reverse: _reverse,
                          child: _entryCard(groups[i].entries[j], data),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagementData {
  const _ManagementData({
    required this.projects,
    required this.stars,
    required this.habits,
    required this.completions,
    required this.today,
  });

  factory _ManagementData.read(
    EntityInsightsController controller,
    InsightEntity? scope,
  ) {
    final insight = scope == null ? null : controller.read(scope);
    final projects =
        [
          ...?insight?.projects,
          if (scope == null) ...controller.projects.getAll(),
        ]..sort((a, b) {
          final byArea = a.area.index.compareTo(b.area.index);
          return byArea != 0 ? byArea : a.displayName.compareTo(b.displayName);
        });
    final habits = scope == null ? controller.habits.getAll() : insight!.habits;
    final habitIds = habits.map((habit) => habit.id).toSet();
    return _ManagementData(
      projects: projects,
      stars: scope == null ? controller.stars.getAll() : insight!.stars,
      habits: habits,
      completions: scope == null
          ? controller.completions
                .getAll()
                .where((entry) => habitIds.contains(entry.habitId))
                .toList()
          : insight!.completions,
      today: insight?.today ?? dateOnly(DateTime.now()),
    );
  }

  final List<Project> projects;
  final List<Star> stars;
  final List<Habit> habits;
  final List<HabitCompletion> completions;
  final DateTime today;

  List<Habit> get activeHabits =>
      habits.where((habit) => habit.isActive).toList();

  int todayCount(Habit habit) => completions
      .where(
        (entry) => entry.habitId == habit.id && dateOnly(entry.date) == today,
      )
      .length;

  bool doneToday(Habit habit) =>
      todayCount(habit) >=
      (habit.frequency == HabitFrequency.daily ? habit.targetPerPeriod : 1);

  int cycleProgress(Habit habit) => habitCycleProgress(
    habit,
    habitCompletionCountsByDay(
      completions.where((entry) => entry.habitId == habit.id).toList(),
    ),
    now: today,
  );
}

class _ManagementGroup {
  const _ManagementGroup(this.project, this.entries);

  final Project project;
  final List<ReaderEntry> entries;
}

class _AreaGroupHeader extends StatelessWidget {
  const _AreaGroupHeader({required this.area});

  final LifeArea area;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AreaIcon(area: area, size: 18),
        const SizedBox(width: kSpaceSm),
        Text(
          area.displayName(context.strings),
          style: context.typography.compactSectionLabel.copyWith(
            color: context.colors.gold,
          ),
        ),
      ],
    );
  }
}

class _ProjectGroupHeader extends StatelessWidget {
  const _ProjectGroupHeader({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          project.iconSlug.isEmpty
              ? Icons.hub_outlined
              : iconForSlug(project.iconSlug),
          size: 16,
          color: context.colors.muted,
        ),
        const SizedBox(width: kSpaceXs),
        Expanded(
          child: Text(
            project.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.compactSectionLabel,
          ),
        ),
      ],
    );
  }
}
