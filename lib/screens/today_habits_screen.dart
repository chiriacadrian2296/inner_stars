import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';

import '../data/reader_entries.dart';
import '../l10n/strings_scope.dart';
import '../models/display_text.dart';
import '../models/habit.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';
import '../utils/entity_insights.dart';
import '../utils/icon_for_slug.dart';
import '../widgets/activity_check_card.dart';
import '../widgets/entity_insight_content.dart';
import '../widgets/entity_insights_scope.dart';
import '../widgets/habit_stepper_dialog.dart';
import '../widgets/responsive_content.dart';
import 'star_reader_screen.dart';

Future<void> openTodayHabits(BuildContext context, InsightEntity entity) async {
  assert(entity.aggregate);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => TodayHabitsScreen(entity: entity)),
  );
}

/// Habits focus on today; goals use the existing achievement flow.
class TodayHabitsScreen extends StatefulWidget {
  const TodayHabitsScreen({super.key, required this.entity});
  final InsightEntity entity;
  @override
  State<TodayHabitsScreen> createState() => _TodayHabitsScreenState();
}

class _TodayHabitsScreenState extends State<TodayHabitsScreen> {
  bool _saving = false;
  bool _goals = false;

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
    final data = controller.read(widget.entity);
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
        photoPath: result.photoPath,
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
    final data = EntityInsightsScope.maybeOf(context)!.read(widget.entity);
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
      final byDate = created(a).compareTo(created(b));
      return byDate == 0 ? a.key.compareTo(b.key) : byDate;
    });
    return entries;
  }

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

  @override
  Widget build(BuildContext context) {
    final controller = EntityInsightsScope.maybeOf(context)!;
    final data = controller.read(widget.entity);
    final entries = _entries(_goals);
    final s = context.strings;
    String? projectName(int id) => widget.entity.kind == InsightEntityKind.area
        ? data.projects.where((p) => p.id == id).firstOrNull?.displayName
        : null;
    return Scaffold(
      backgroundColor: context.colors.night,
      body: SafeArea(
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
                  child: AnimatedToggleSwitch<bool>.rolling(
                    current: _goals,
                    values: const [false, true],
                    height: 40,
                    indicatorSize: const Size(120, 40),
                    borderWidth: kBorderWidth,
                    iconOpacity: 1,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _goals = value),
                    iconBuilder: (value, size) => Semantics(
                      selected: value == _goals,
                      child: Tooltip(
                        message: value ? s.manageGoals : s.manageHabits,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value ? s.cardBadgeGoals : s.cardBadgeHabits,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: value == _goals
                                  ? context.colors.night
                                  : context.colors.muted,
                            ),
                          ),
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
                const SizedBox(height: 20),
                Text(
                  insightTitle(context, data),
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
                  Text(
                    _goals ? s.manageGoalsEmpty : s.insightNoHabits,
                    style: TextStyle(color: context.colors.muted),
                  ),
                for (final entry in entries)
                  Padding(
                    key: ValueKey(entry.key),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: switch (entry) {
                      PulsarEntry(:final habit) => ActivityCheckCard(
                        icon: habit.iconSlug.isEmpty
                            ? StarKind.pulsar.icon
                            : iconForSlug(habit.iconSlug),
                        title: habit.displayTitle,
                        lit: data.doneToday(habit),
                        subtitle: projectName(habit.projectId),
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
                            // How far the current cycle is.
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
                            habit.frequency == HabitFrequency.daily &&
                                habit.targetPerPeriod > 1
                            ? Icons.add_circle_outline
                            : data.doneToday(habit)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        actionLabel:
                            habit.frequency == HabitFrequency.daily &&
                                habit.targetPerPeriod > 1
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
                        subtitle: projectName(star.projectId),
                        onTap: _saving ? null : () => _view(entry),
                        actionIcon: star.isLit
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        actionLabel: star.isLit
                            ? s.habitUncheckAction
                            : s.completeActivityAction,
                        onAction: _saving
                            ? null
                            : () => star.isLit
                                  ? _unachieve(star)
                                  : _achieve(star),
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
