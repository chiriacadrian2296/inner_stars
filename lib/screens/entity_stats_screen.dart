import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/display_text.dart';
import '../models/habit_cycle.dart';
import '../models/life_area.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/entity_insights.dart';
import '../utils/habit_stats.dart';
import '../utils/icon_for_slug.dart';
import '../utils/star_stats.dart' show cycleIntensityTotal;
import '../widgets/habit_cycle_scope.dart';
import '../widgets/activity_check_card.dart';
import '../widgets/entity_insight_content.dart';
import '../widgets/entity_insights_scope.dart';
import '../widgets/responsive_content.dart';
import '../widgets/stats/stats_widgets.dart';
import '../widgets/star_type_text.dart';
import 'pulsar_reader_screen.dart' show HabitAnalytics;
import 'today_habits_screen.dart';

Future<void> openEntityStatistics(
  BuildContext context,
  InsightEntity entity,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => EntityStatsScreen(entity: entity)),
  );
}

class EntityStatsScreen extends StatefulWidget {
  const EntityStatsScreen({super.key, required this.entity});
  final InsightEntity entity;
  @override
  State<EntityStatsScreen> createState() => _EntityStatsScreenState();
}

class _EntityStatsScreenState extends State<EntityStatsScreen> {
  HabitStatsRange _range = HabitStatsRange.days30;
  @override
  Widget build(BuildContext context) {
    final controller = EntityInsightsScope.maybeOf(context)!;
    final data = controller.read(widget.entity, range: _range);
    final habit = data.habits.firstOrNull;
    final habitCycles = habit == null
        ? const <HabitCycle>[]
        : HabitCycleScope.maybeOf(context)?.getAllForHabit(habit.id) ??
              const <HabitCycle>[];
    final star = data.stars.firstOrNull;
    final project = widget.entity.kind == InsightEntityKind.project
        ? data.projects.firstOrNull
        : data.projects
              .where((p) => p.id == (star?.projectId ?? habit?.projectId))
              .firstOrNull;
    final strings = context.strings;
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
                  strings.statsTitle,
                  style: context.typography.utilityPageTitle,
                ),
                const SizedBox(height: 20),
                StarTypeText(
                  insightType(context, data),
                  originalKind: star?.dead == true
                      ? star!.originalKind
                      : habit?.dead == true
                      ? StarKind.pulsar
                      : null,
                  style: TextStyle(color: context.colors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  insightTitle(context, data),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.colors.text,
                  ),
                ),
                if (project != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.entity.kind == InsightEntityKind.project
                        ? project.area.displayName(strings)
                        : '${project.area.displayName(strings)} → ${project.displayName}',
                    style: TextStyle(color: context.colors.muted),
                  ),
                ],
                const SizedBox(height: 20),
                if (widget.entity.aggregate)
                  RangeChips(
                    range: _range,
                    onChanged: (range) => setState(() => _range = range),
                  ),
                EntityInsightMetrics(data: data),
                if (widget.entity.aggregate) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.checklist_rounded),
                    label: Text(strings.manageHabits),
                    onPressed: () => openTodayHabits(context, widget.entity),
                  ),
                  const SizedBox(height: 20),
                  StatsSectionLabel(
                    '${strings.insightRecentVictories} · ${strings.habitStatsDays(_range.days)}',
                  ),
                  HeatmapPanel(
                    countsByDay: data.victoryDays,
                    availableFrom: data.start,
                    availableThrough: data.today,
                  ),
                  const SizedBox(height: 20),
                  StatsSectionLabel(strings.habitStatsSectionTitle),
                  if (data.activeHabits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(strings.insightNoHabits),
                    ),
                  for (final activeHabit in data.activeHabits)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ActivityCheckCard(
                        icon: activeHabit.iconSlug.isEmpty
                            ? StarKind.pulsar.icon
                            : iconForSlug(activeHabit.iconSlug),
                        title: activeHabit.displayTitle,
                        lit: data.doneToday(activeHabit),
                        figures: Text(
                          data.summary(activeHabit).trend.isEmpty
                              ? strings.insightNoData
                              : '${data.cycleProgress(activeHabit).clamp(0, activeHabit.cycleLength)}/${activeHabit.cycleLength}',
                          style: TextStyle(color: context.colors.text),
                        ),
                        onTap: () => openEntityStatistics(
                          context,
                          InsightEntity.habit(activeHabit.id),
                        ),
                      ),
                    ),
                ],
                if (habit != null) ...[
                  const SizedBox(height: 20),
                  if (data.daysDone == null)
                    Text(strings.insightNoData)
                  else
                    HabitAnalytics(
                      habit: habit,
                      summary: data.summary(habit),
                      range: _range,
                      onRangeChanged: (range) => setState(() => _range = range),
                      completedCycles: habitCycles.length,
                      rewardEarned: cycleIntensityTotal(habitCycles),
                    ),
                  const SizedBox(height: 20),
                  HeatmapPanel(
                    countsByDay: habitCompletionCountsByDay(data.completions),
                    progressByDay: habitProgressByDay(
                      habit,
                      habitCompletionCountsByDay(data.completions),
                    ),
                    availableFrom: habit.createdAt,
                    availableThrough: habit.deadDate,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
