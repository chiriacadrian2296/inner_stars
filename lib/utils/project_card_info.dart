import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/constellation_layout.dart' show kMaxConstellationStars;
import '../l10n/app_strings.dart';
import '../models/habit.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../widgets/star_glyph.dart' show starKindColor;
import 'date_format.dart';
import 'habit_stats.dart';
import 'star_card_info.dart';

/// How many of [habits] (the living ones) are lit right now, and how many
/// there are.
({int lit, int total}) _pulsarsToday(
  List<Habit> habits,
  Map<int, Map<DateTime, int>> countsByHabit,
  DateTime today,
) {
  var lit = 0;
  var total = 0;
  for (final habit in habits) {
    if (habit.dead) continue;
    total++;
    if (isHabitLit(habit, countsByHabit[habit.id] ?? const {}, now: today)) {
      lit++;
    }
  }
  return (lit: lit, total: total);
}

CardBadge _pulsarsBadge(
  ({int lit, int total}) pulsars,
  AppColors colors,
  AppStrings strings,
) => CardBadge(
  icon: Icons.local_fire_department_rounded,
  value: '${pulsars.lit}/${pulsars.total}',
  iconColor: starKindColor(
    StarKind.pulsar,
    colors,
    lit: pulsars.lit == pulsars.total,
  ),
  valueColor: colors.text,
  semanticLabel: strings.cardBadgePulsarsToday,
);

/// The badges for a constellation: lit stars out of the most it can hold, open goals,
/// empty slots, habits lit today, the next goal date, the total intensity,
/// memories and dead stars. Only facts — a badge appears when there is
/// something to say. [slotCount] is the shape's number of points (0 when it
/// has none). Pure data, from caches: no I/O.
List<CardBadge> projectCardBadges({
  required List<Star> stars,
  required List<Habit> habits,
  required Map<int, Map<DateTime, int>> countsByHabit,
  required int slotCount,
  required AppColors colors,
  required AppStrings strings,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final text = colors.text;
  final lit = stars.where((s) => s.isLit).toList();
  final goals = stars.where((s) => s.isUnlit).toList();
  final dead = stars.where((s) => s.dead).length;
  // Out of what the constellation can hold, not out of the shape's own
  // points: stars past those grow the shape, so the points alone would give
  // "12/8". Older constellations already past the cap show their own count.
  final total = math.max(kMaxConstellationStars, stars.length);

  final badges = <CardBadge>[
    CardBadge(
      icon: Icons.star_rounded,
      value: '${lit.length}/$total',
      iconColor: colors.gold,
      valueColor: text,
      semanticLabel: strings.cardBadgeLitStars,
    ),
  ];
  if (goals.isNotEmpty) {
    badges.add(
      CardBadge(
        icon: Icons.star_outline_rounded,
        value: '${goals.length}',
        iconColor: colors.starUnlit,
        valueColor: text,
        semanticLabel: strings.cardBadgeGoals,
        secondary: true,
      ),
    );
  }
  final empty = slotCount - stars.length;
  if (empty > 0) {
    badges.add(
      CardBadge(
        icon: Icons.circle_outlined,
        value: '$empty',
        iconColor: colors.starNascent,
        valueColor: text,
        semanticLabel: strings.cardBadgeEmptySlots,
        secondary: true,
      ),
    );
  }
  final pulsars = _pulsarsToday(habits, countsByHabit, today);
  if (pulsars.total > 0) badges.add(_pulsarsBadge(pulsars, colors, strings));

  DateTime? next;
  for (final goal in goals) {
    final date = goal.targetDate;
    if (date == null) continue;
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(today)) continue;
    if (next == null || day.isBefore(next)) next = day;
  }
  if (next != null) {
    badges.add(
      CardBadge(
        icon: Icons.event_outlined,
        value: formatDisplayDate(next, strings),
        iconColor: colors.gold,
        valueColor: text,
        semanticLabel: strings.cardBadgeNextDate,
        secondary: true,
      ),
    );
  }
  final energy = lit.fold<int>(0, (sum, s) => sum + (s.intensity ?? 0));
  if (energy > 0) {
    badges.add(
      CardBadge(
        icon: Icons.bolt_rounded,
        value: '$energy',
        iconColor: colors.gold,
        valueColor: text,
        semanticLabel: strings.cardBadgeEnergy,
        secondary: true,
      ),
    );
  }
  final memories = lit.fold<int>(
    0,
    (sum, s) =>
        sum +
        (s.photoPath != null ? 1 : 0) +
        s.mediaCount(StarMediaKind.photo) +
        s.mediaCount(StarMediaKind.video) +
        s.mediaCount(StarMediaKind.voice) +
        s.mediaCount(StarMediaKind.link),
  );
  if (memories > 0) {
    badges.add(
      CardBadge(
        icon: Icons.photo_library_outlined,
        value: '$memories',
        iconColor: colors.gold,
        valueColor: text,
        semanticLabel: strings.cardBadgeMemories,
        secondary: true,
      ),
    );
  }
  if (dead > 0) {
    badges.add(
      CardBadge(
        icon: Icons.cancel_outlined,
        value: '$dead',
        iconColor: colors.starDead,
        valueColor: text,
        semanticLabel: strings.cardBadgeDeadStars,
        secondary: true,
      ),
    );
  }
  return badges;
}

/// The badges for an area (supernova): its constellations, lit stars out of
/// all its stars, habits lit today, stars lit this month, answered
/// reflections, a written vision and moodboard items. Only what exists is
/// shown — an empty vision or moodboard leaves no badge. Pure data, from
/// caches: no I/O.
List<CardBadge> areaCardBadges({
  required int constellationCount,
  required List<Star> stars,
  required List<Habit> habits,
  required Map<int, Map<DateTime, int>> countsByHabit,
  required int reflectionsAnswered,
  required bool hasVision,
  required int moodboardCount,
  required AppColors colors,
  required AppStrings strings,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final text = colors.text;
  final lit = stars.where((s) => s.isLit).toList();
  final goals = stars.where((s) => s.isUnlit).length;

  final badges = <CardBadge>[
    CardBadge(
      icon: Icons.insights_outlined,
      value: '$constellationCount',
      iconColor: colors.gold,
      valueColor: text,
      semanticLabel: strings.cardBadgeConstellations,
    ),
    CardBadge(
      icon: Icons.star_rounded,
      value: '${lit.length}/${lit.length + goals}',
      iconColor: colors.gold,
      valueColor: text,
      semanticLabel: strings.cardBadgeLitStars,
    ),
  ];
  final pulsars = _pulsarsToday(habits, countsByHabit, today);
  if (pulsars.total > 0) badges.add(_pulsarsBadge(pulsars, colors, strings));

  final thisMonth = lit.where((s) {
    final date = s.achievedDate;
    return date != null && date.year == today.year && date.month == today.month;
  }).length;
  if (thisMonth > 0) {
    badges.add(
      CardBadge(
        icon: Icons.calendar_month_rounded,
        value: '$thisMonth',
        iconColor: colors.gold,
        valueColor: text,
        semanticLabel: strings.cardBadgeThisMonth,
        secondary: true,
      ),
    );
  }
  if (reflectionsAnswered > 0) {
    badges.add(
      CardBadge(
        icon: Icons.auto_stories_outlined,
        value: '$reflectionsAnswered',
        iconColor: colors.gold,
        valueColor: text,
        semanticLabel: strings.cardBadgeReflections,
        secondary: true,
      ),
    );
  }
  if (hasVision) {
    badges.add(
      CardBadge(
        icon: Icons.edit_outlined,
        iconColor: colors.gold,
        valueColor: text,
        semanticLabel: strings.cardBadgeVision,
        secondary: true,
      ),
    );
  }
  if (moodboardCount > 0) {
    badges.add(
      CardBadge(
        icon: Icons.photo_library_outlined,
        value: '$moodboardCount',
        iconColor: colors.gold,
        valueColor: text,
        semanticLabel: strings.cardBadgeMoodboard,
        secondary: true,
      ),
    );
  }
  return badges;
}
