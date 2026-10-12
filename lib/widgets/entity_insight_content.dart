import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/display_text.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/star_kind.dart';
import '../utils/date_math.dart';
import '../utils/entity_insights.dart';
import '../theme/app_colors.dart';

String insightTitle(BuildContext context, EntityInsights data) {
  if (data.entity.area != null) {
    return data.entity.area!.displayName(context.strings);
  }
  if (data.entity.kind == InsightEntityKind.project) {
    return data.projects.firstOrNull?.displayName ??
        context.strings.insightUnavailable;
  }
  return data.stars.firstOrNull?.displayTitle ??
      data.habits.firstOrNull?.displayTitle ??
      context.strings.insightUnavailable;
}

String insightType(BuildContext context, EntityInsights data) =>
    switch (data.entity.kind) {
      InsightEntityKind.area => context.strings.areaLabel,
      InsightEntityKind.project => context.strings.projectLabel,
      InsightEntityKind.star =>
        data.stars.firstOrNull?.kind.label(context.strings) ?? '',
      InsightEntityKind.habit =>
        (data.habits.firstOrNull?.dead == true
                ? StarKind.dead
                : StarKind.pulsar)
            .label(context.strings),
    };

List<({String label, String value})> insightMetrics(
  BuildContext context,
  EntityInsights data,
) {
  final s = context.strings;
  String rate() => data.consistency == null
      ? s.insightNoData
      : '${(data.consistency! * 100).round()}%';
  String date(DateTime? value) => value == null
      ? s.insightNoData
      : MaterialLocalizations.of(context).formatMediumDate(value);
  String days(DateTime from, DateTime to) => to.isBefore(from)
      ? s.insightNoData
      : s.habitStatsDays(dateOnly(to).difference(dateOnly(from)).inDays);
  if (data.entity.aggregate) {
    return [
      (label: s.cardBadgeLitStars, value: '${data.victories}'),
      (label: s.cardBadgeGoals, value: '${data.goals}'),
      (label: s.habitStatsActiveLabel, value: '${data.activeHabits.length}'),
      (
        label: s.insightTodayHabits,
        value: '${data.habitsDoneToday}/${data.activeHabits.length}',
      ),
      (
        label:
            '${s.insightRecentVictories} · ${s.habitStatsDays(data.range.days)}',
        value: '${data.recentVictories}',
      ),
      (
        label:
            '${s.habitStatsConsistencyLabel} · ${s.habitStatsDays(data.range.days)}',
        value: rate(),
      ),
    ];
  }
  final habit = data.habits.firstOrNull;
  if (habit != null) {
    return [
      if (habit.dead) (label: s.detailsLabel, value: StarKind.pulsar.label(s)),
      if (!habit.dead)
        (
          label: s.todayLabel,
          value:
              habit.frequency == HabitFrequency.daily &&
                  habit.targetPerPeriod > 1
              ? '${data.todayCount(habit)}/${habit.targetPerPeriod}'
              : data.doneToday(habit)
              ? s.habitDoneTodayLabel
              : s.habitStillToDoLabel,
        ),
      (
        label: s.habitFrequencyLabel,
        value:
            '${habit.targetPerPeriod} · ${habit.frequency == HabitFrequency.daily ? s.habitFrequencyDaily : s.habitFrequencyWeekly}',
      ),
      (
        label:
            '${s.habitStatsConsistencyLabel} · ${s.habitStatsDays(data.range.days)}',
        value: rate(),
      ),
      if (habit.dead) (label: s.insightArchived, value: date(habit.deadDate)),
      if (habit.dead)
        (label: s.habitStatsTotalLabel, value: '${data.completions.length}'),
    ];
  }
  final star = data.stars.firstOrNull;
  if (star == null) return [(label: s.insightNoData, value: '—')];
  return [
    if (star.dead) (label: s.detailsLabel, value: star.originalKind.label(s)),
    (label: s.insightCreated, value: date(star.createdAt)),
    if (star.achievedDate != null) ...[
      (label: s.insightAchieved, value: date(star.achievedDate)),
      (
        label: s.intensityLabel,
        value: star.intensity == null ? s.insightNoData : '${star.intensity}/5',
      ),
      (
        label: s.insightDuration,
        value: days(star.createdAt, star.achievedDate!),
      ),
    ] else
      (
        label: s.insightElapsed,
        value: days(
          star.createdAt,
          star.dead ? star.deadDate ?? data.now : data.now,
        ),
      ),
    if (star.dead) (label: s.insightArchived, value: date(star.deadDate)),
  ];
}

class EntityInsightMetrics extends StatelessWidget {
  const EntityInsightMetrics({
    super.key,
    required this.data,
    this.compact = false,
  });
  final EntityInsights data;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final metric in insightMetrics(context, data))
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 5 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: TextStyle(
                  fontSize: compact ? 11 : 13,
                  color: context.colors.muted,
                ),
              ),
              Text(
                metric.value,
                style: TextStyle(
                  fontSize: compact ? 14 : 20,
                  color: context.colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
