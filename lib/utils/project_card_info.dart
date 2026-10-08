import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/constellation_layout.dart' show kMaxConstellationStars;
import '../l10n/app_strings.dart';
import '../models/habit.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../widgets/star_glyph.dart' show starKindColor;
import 'badge_schema.dart';
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

/// How many empty slots a constellation of [stars] has when its shape has
/// [slotCount] points (0 when it has none).
int emptySlotsOf(int slotCount, List<Star> stars) =>
    math.max(0, slotCount - stars.length);

/// The total intensity of the lit [stars]: a constellation's or an area's.
int _energy(List<Star> stars) => stars
    .where((s) => s.isLit)
    .fold<int>(0, (sum, s) => sum + (s.intensity ?? 0));

CardBadge _goalsBadge(int goals, AppColors colors, AppStrings strings) =>
    _count(
      BadgeSlot.goals,
      Icons.star_outline_rounded,
      goals,
      colors.starUnlit,
      colors,
      strings.cardBadgeGoals,
    );

CardBadge _emptySlotsBadge(int empty, AppColors colors, AppStrings strings) =>
    _count(
      BadgeSlot.emptySlots,
      Icons.circle_outlined,
      empty,
      colors.starNascent,
      colors,
      strings.cardBadgeEmptySlots,
    );

CardBadge _deadStarsBadge(int dead, AppColors colors, AppStrings strings) =>
    _count(
      BadgeSlot.deadStars,
      StarKind.dead.icon,
      dead,
      colors.starDead,
      colors,
      strings.cardBadgeDeadStars,
    );

/// The badges for a constellation: the total intensity of its lit stars, then
/// one fixed row — lit stars out of what it can hold, habits lit today, open
/// goals, empty slots, dead stars. All of them are always there, a zero when
/// there is nothing. [slotCount] is the shape's number of points (0 when it
/// has none). Pure data, from caches: no I/O.
CardBadges projectCardBadges({
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
  final lit = stars.where((s) => s.isLit).length;
  final goals = stars.where((s) => s.isUnlit).length;
  final dead = stars.where((s) => s.dead).length;
  // Out of what the constellation can hold, not out of the shape's own
  // points: stars past those grow the shape, so the points alone would give
  // "12/8". Older constellations already past the cap show their own count.
  final total = math.max(kMaxConstellationStars, stars.length);

  return CardBadges(
    intensity: intensityBadge(_energy(stars), colors, strings),
    rows: [
      [
        makeBadge(
          BadgeSlot.litOfTotal,
          Icons.star_rounded,
          colors,
          color: colors.gold,
          value: '$lit/$total',
          zero: lit == 0,
          label: strings.cardBadgeLitStars,
        ),
        _pulsarsBadge(
          _pulsarsToday(habits, countsByHabit, today),
          colors,
          strings,
        ),
        _goalsBadge(goals, colors, strings),
        _emptySlotsBadge(emptySlotsOf(slotCount, stars), colors, strings),
        _deadStarsBadge(dead, colors, strings),
      ],
    ],
  );
}

/// The badges for an area (supernova): the total intensity of its lit stars,
/// then one fixed row — its constellations, lit stars, living habits, open
/// goals, empty slots (over all its constellations, [emptySlots]) and dead
/// stars. All of them are always there. Pure data, from caches: no I/O.
CardBadges areaCardBadges({
  required int constellationCount,
  required List<Star> stars,
  required List<Habit> habits,
  required int emptySlots,
  required AppColors colors,
  required AppStrings strings,
}) {
  final lit = stars.where((s) => s.isLit).length;
  final goals = stars.where((s) => s.isUnlit).length;
  final dead = stars.where((s) => s.dead).length;

  return CardBadges(
    intensity: intensityBadge(_energy(stars), colors, strings),
    rows: [
      [
        _count(
          BadgeSlot.constellations,
          Icons.insights_outlined,
          constellationCount,
          colors.gold,
          colors,
          strings.cardBadgeConstellations,
        ),
        _count(
          BadgeSlot.litStars,
          Icons.star_rounded,
          lit,
          colors.gold,
          colors,
          strings.cardBadgeLitStars,
        ),
        _count(
          BadgeSlot.habits,
          Icons.local_fire_department_rounded,
          habits.where((h) => !h.dead).length,
          starKindColor(StarKind.pulsar, colors),
          colors,
          strings.cardBadgeHabits,
        ),
        _goalsBadge(goals, colors, strings),
        _emptySlotsBadge(emptySlots, colors, strings),
        _deadStarsBadge(dead, colors, strings),
      ],
    ],
  );
}
