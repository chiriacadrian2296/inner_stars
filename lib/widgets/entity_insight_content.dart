import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/display_text.dart';
import '../models/life_area.dart';
import '../models/star_kind.dart';
import '../utils/date_math.dart';
import '../utils/entity_insights.dart';
import '../utils/star_stats.dart' show cycleIntensityTotal;
import 'habit_cycle_scope.dart';
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
  final cycles = HabitCycleScope.maybeOf(context)?.getAll() ?? const [];
  String date(DateTime? value) => value == null
      ? '—'
      : MaterialLocalizations.of(context).formatMediumDate(value);
  // Only what was done, in the same words as "Your Light": intensity,
  // victories, cycles, days done. No open goals, no "today" fractions, no
  // rhythm wish, no time elapsed on an unreached goal.
  if (data.entity.aggregate) {
    final habitIds = {for (final h in data.habits) h.id};
    return [
      // Stars and completed pulsar cycles both add to an area's or
      // constellation's intensity.
      (
        label: s.intensityLabel,
        value:
            '${data.starIntensity + cycleIntensityTotal(cycles, habitIds: habitIds)}',
      ),
      (label: s.cardBadgeLitStars, value: '${data.victories}'),
      (
        label: s.habitStatsCyclesLabel,
        value: '${cycles.where((c) => habitIds.contains(c.habitId)).length}',
      ),
    ];
  }
  final habit = data.habits.firstOrNull;
  if (habit != null) {
    return [
      (
        label: s.habitStatsDaysDoneLabel,
        // Every day with a check-in, ever.
        value: '${{for (final c in data.completions) dateOnly(c.date)}.length}',
      ),
      if (!habit.dead)
        (
          label: s.habitCycleLabel,
          value: s.cycleProgressLabel(
            data.cycleProgress(habit).clamp(0, habit.cycleLength),
            habit.cycleLength,
          ),
        ),
      (
        label: s.habitStatsCyclesLabel,
        value: '${cycles.where((c) => c.habitId == habit.id).length}',
      ),
      if (habit.dead) (label: s.insightArchived, value: date(habit.deadDate)),
    ];
  }
  final star = data.stars.firstOrNull;
  if (star == null) return [(label: s.insightNoData, value: '—')];
  return [
    if (star.dead) (label: s.detailsLabel, value: star.originalKind.label(s)),
    if (star.achievedDate != null) ...[
      (label: s.insightAchieved, value: date(star.achievedDate)),
      if (star.intensity != null)
        (label: s.intensityLabel, value: '${star.intensity}/5'),
    ],
    (label: s.insightCreated, value: date(star.createdAt)),
    if (star.dead) (label: s.insightArchived, value: date(star.deadDate)),
  ];
}

class EntityInsightMetrics extends StatelessWidget {
  const EntityInsightMetrics({
    super.key,
    required this.data,
    this.compact = false,
    this.tooltip = false,
  });
  final EntityInsights data;
  final bool compact;
  final bool tooltip;
  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final metrics = insightMetrics(context, data);
    final displayedMetrics = metrics;
    final habit = data.habits.firstOrNull;
    IconData icon(String label) {
      if (label == s.cardBadgeLitStars) return Icons.auto_awesome_rounded;
      if (label == s.habitStatsDaysDoneLabel) {
        return Icons.event_available_rounded;
      }
      if (label == s.habitCycleLabel || label == s.habitStatsCyclesLabel) {
        return Icons.sync_rounded;
      }
      if (label == s.intensityLabel) return Icons.bolt_rounded;
      if (label == s.insightArchived) return Icons.archive_outlined;
      if (label == s.detailsLabel) return Icons.category_outlined;
      return Icons.calendar_today_outlined;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = tooltip
            ? 8.0
            : compact
            ? 6.0
            : 10.0;
        // Wider text needs wider badges; narrow cards fall back to one column.
        final minWidth =
            (tooltip
                ? 90.0
                : compact
                ? 40.0
                : 130.0) *
            MediaQuery.textScalerOf(context).scale(1);
        final columns = (constraints.maxWidth / (minWidth + gap)).floor().clamp(
          1,
          tooltip && data.entity.aggregate ? 3 : 2,
        );
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in displayedMetrics)
              Builder(
                builder: (context) {
                  final cycle = metric.label == s.habitCycleLabel;
                  final date =
                      metric.label == s.insightCreated ||
                      metric.label == s.insightAchieved ||
                      metric.label == s.insightArchived ||
                      metric.label == s.detailsLabel;
                  // The current cycle's bar is progress toward a reward,
                  // never a measure of what is missing.
                  final progress =
                      cycle && habit != null && habit.cycleLength > 0
                      ? data.cycleProgress(habit) / habit.cycleLength
                      : null;
                  return SizedBox(
                    width: !tooltip && (cycle || date)
                        ? constraints.maxWidth
                        : width,
                    child: _InsightBadge(
                      label: metric.label,
                      value: metric.value,
                      icon: icon(metric.label),
                      compact: compact,
                      tooltip: tooltip,
                      inline: date && !tooltip,
                      // Gold for every figure of what was done; dates stay plain.
                      iconColor: date
                          ? context.colors.text
                          : context.colors.gold,
                      progress: progress?.clamp(0.0, 1.0),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _InsightBadge extends StatelessWidget {
  const _InsightBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.compact,
    required this.tooltip,
    required this.inline,
    required this.iconColor,
    this.progress,
  });
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final bool compact, inline, tooltip;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = iconColor;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(
          tooltip
              ? 7
              : compact
              ? 5
              : 8,
        ),
        decoration: BoxDecoration(
          color: colors.night,
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          border: Border.all(color: colors.nightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: tooltip
                      ? 14
                      : compact
                      ? 12
                      : 16,
                  color: accent,
                ),
                SizedBox(width: compact ? 4 : 6),
                Expanded(
                  child: Text(
                    inline ? label : value,
                    style: TextStyle(
                      fontSize: inline
                          ? (compact ? 9 : 11)
                          : (tooltip
                                ? 13
                                : compact
                                ? 12
                                : 16),
                      height: 1.15,
                      fontWeight: inline ? FontWeight.normal : FontWeight.w600,
                      color: inline ? colors.muted : colors.text,
                    ),
                  ),
                ),
                if (inline) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: compact ? 10.5 : 13,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (!inline) ...[
              const SizedBox(height: 3),
              Tooltip(
                message: label,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tooltip
                        ? 10
                        : compact
                        ? 9
                        : 11,
                    color: colors.muted,
                    height: 1.15,
                  ),
                ),
              ),
            ],
            if (progress != null) ...[
              SizedBox(height: compact ? 5 : 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: compact ? 3 : 4,
                  color: accent,
                  backgroundColor: colors.nightBorder,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
