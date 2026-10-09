import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/habit.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../widgets/star_glyph.dart' show starKindColor;
import 'badge_schema.dart';
import 'star_card_info.dart';

/// The habits badge: how many living [habits] there are. The fire is half
/// gold, half navy — a habit is lit one day and dark the next.
CardBadge _habitsBadge(
  List<Habit> habits,
  AppColors colors,
  AppStrings strings,
) {
  final count = habits.where((h) => !h.dead).length;
  return makeBadge(
    BadgeSlot.habits,
    Icons.local_fire_department_rounded,
    colors,
    color: starKindColor(StarKind.pulsar, colors),
    colorEnd: starKindColor(StarKind.pulsar, colors, lit: false),
    value: '$count',
    zero: count == 0,
    label: strings.cardBadgeHabits,
  );
}

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

/// The badges for a constellation: the total intensity of its lit stars,
/// then one fixed row — its lit stars, habits, open goals, empty slots and
/// dead stars, all plain counts (as on an area). All of them are always
/// there, a zero when there is nothing. [slotCount] is the shape's number of
/// points (0 when it has none). Pure data, from caches: no I/O.
CardBadges projectCardBadges({
  required List<Star> stars,
  required List<Habit> habits,
  required int slotCount,
  required AppColors colors,
  required AppStrings strings,
}) {
  return CardBadges(
    intensity: intensityBadge(_energy(stars), colors, strings),
    rows: [
      [
        _count(
          BadgeSlot.litStars,
          Icons.star_rounded,
          stars.where((s) => s.isLit).length,
          colors.gold,
          colors,
          strings.cardBadgeLitStars,
        ),
        _habitsBadge(habits, colors, strings),
        _goalsBadge(stars.where((s) => s.isUnlit).length, colors, strings),
        _emptySlotsBadge(emptySlotsOf(slotCount, stars), colors, strings),
        _deadStarsBadge(stars.where((s) => s.dead).length, colors, strings),
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
    title: _count(
      BadgeSlot.constellations,
      Icons.insights_outlined,
      constellationCount,
      colors.gold,
      colors,
      strings.cardBadgeConstellations,
    ),
    rows: [
      [
        _count(
          BadgeSlot.litStars,
          Icons.star_rounded,
          lit,
          colors.gold,
          colors,
          strings.cardBadgeLitStars,
        ),
        _habitsBadge(habits, colors, strings),
        _goalsBadge(goals, colors, strings),
        _emptySlotsBadge(emptySlots, colors, strings),
        _deadStarsBadge(dead, colors, strings),
      ],
    ],
  );
}
