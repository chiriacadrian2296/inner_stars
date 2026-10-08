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
import 'badge_schema.dart';
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
) => makeBadge(
  BadgeSlot.pulsarsToday,
  Icons.local_fire_department_rounded,
  colors,
  color: starKindColor(
    StarKind.pulsar,
    colors,
    lit: pulsars.total > 0 && pulsars.lit == pulsars.total,
  ),
  value: '${pulsars.lit}/${pulsars.total}',
  zero: pulsars.total == 0,
  label: strings.cardBadgePulsarsToday,
);

/// A count badge: muted when it is nothing.
CardBadge _count(
  BadgeSlot slot,
  IconData icon,
  int count,
  Color color,
  AppColors colors,
  String label,
) => makeBadge(
  slot,
  icon,
  colors,
  color: color,
  value: '$count',
  zero: count == 0,
  label: label,
);

/// The badges for a constellation, in two fixed rows (see [kBadgeRows]):
/// the state of its stars — lit out of what it can hold, open goals, empty
/// slots, dead stars — then its activity — the next goal date, habits lit
/// today, the total intensity, memories. All eight are always there, a zero
/// or a dash when there is nothing. [slotCount] is the shape's number of
/// points (0 when it has none). Pure data, from caches: no I/O.
List<List<CardBadge>> projectCardBadges({
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
  final lit = stars.where((s) => s.isLit).toList();
  final goals = stars.where((s) => s.isUnlit).toList();
  final dead = stars.where((s) => s.dead).length;
  // Out of what the constellation can hold, not out of the shape's own
  // points: stars past those grow the shape, so the points alone would give
  // "12/8". Older constellations already past the cap show their own count.
  final total = math.max(kMaxConstellationStars, stars.length);

  DateTime? next;
  for (final goal in goals) {
    final date = goal.targetDate;
    if (date == null) continue;
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(today)) continue;
    if (next == null || day.isBefore(next)) next = day;
  }
  final energy = lit.fold<int>(0, (sum, s) => sum + (s.intensity ?? 0));
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

  return [
    [
      makeBadge(
        BadgeSlot.litOfTotal,
        Icons.star_rounded,
        colors,
        color: colors.gold,
        value: '${lit.length}/$total',
        zero: lit.isEmpty,
        label: strings.cardBadgeLitStars,
      ),
      _count(
        BadgeSlot.goals,
        Icons.star_outline_rounded,
        goals.length,
        colors.starUnlit,
        colors,
        strings.cardBadgeGoals,
      ),
      _count(
        BadgeSlot.emptySlots,
        Icons.circle_outlined,
        math.max(0, slotCount - stars.length),
        colors.starNascent,
        colors,
        strings.cardBadgeEmptySlots,
      ),
      _count(
        BadgeSlot.deadStars,
        StarKind.dead.icon,
        dead,
        colors.starDead,
        colors,
        strings.cardBadgeDeadStars,
      ),
    ],
    [
      makeBadge(
        BadgeSlot.nextDate,
        Icons.event_outlined,
        colors,
        color: colors.gold,
        value: next == null
            ? '—'
            : (next.year == today.year
                  ? formatShortDate(next)
                  : formatShortDateWithYear(next)),
        zero: next == null,
        label: strings.cardBadgeNextDate,
      ),
      _pulsarsBadge(
        _pulsarsToday(habits, countsByHabit, today),
        colors,
        strings,
      ),
      _count(
        BadgeSlot.energy,
        Icons.bolt_rounded,
        energy,
        colors.gold,
        colors,
        strings.cardBadgeEnergy,
      ),
      _count(
        BadgeSlot.memories,
        Icons.photo_library_outlined,
        memories,
        colors.gold,
        colors,
        strings.cardBadgeMemories,
      ),
    ],
  ];
}

/// The badges for an area (supernova), in two fixed rows (see
/// [kBadgeRows]): its constellations, lit stars out of all its stars and
/// habits lit today; then stars lit this month, answered reflections, a
/// written vision (✓ or ✗) and moodboard items. All seven are always there.
/// Pure data, from caches: no I/O.
List<List<CardBadge>> areaCardBadges({
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
  final lit = stars.where((s) => s.isLit).toList();
  final goals = stars.where((s) => s.isUnlit).length;
  final thisMonth = lit.where((s) {
    final date = s.achievedDate;
    return date != null && date.year == today.year && date.month == today.month;
  }).length;

  return [
    [
      _count(
        BadgeSlot.constellations,
        Icons.insights_outlined,
        constellationCount,
        colors.gold,
        colors,
        strings.cardBadgeConstellations,
      ),
      makeBadge(
        BadgeSlot.litOfTotal,
        Icons.star_rounded,
        colors,
        color: colors.gold,
        value: '${lit.length}/${lit.length + goals}',
        zero: lit.isEmpty,
        label: strings.cardBadgeLitStars,
      ),
      _pulsarsBadge(
        _pulsarsToday(habits, countsByHabit, today),
        colors,
        strings,
      ),
    ],
    [
      _count(
        BadgeSlot.thisMonth,
        Icons.calendar_month_rounded,
        thisMonth,
        colors.gold,
        colors,
        strings.cardBadgeThisMonth,
      ),
      _count(
        BadgeSlot.reflections,
        Icons.auto_stories_outlined,
        reflectionsAnswered,
        colors.gold,
        colors,
        strings.cardBadgeReflections,
      ),
      makeBadge(
        BadgeSlot.vision,
        Icons.edit_outlined,
        colors,
        color: colors.gold,
        check: hasVision,
        zero: !hasVision,
        label: strings.cardBadgeVision,
      ),
      _count(
        BadgeSlot.moodboard,
        Icons.photo_library_outlined,
        moodboardCount,
        colors.gold,
        colors,
        strings.cardBadgeMoodboard,
      ),
    ],
  ];
}
